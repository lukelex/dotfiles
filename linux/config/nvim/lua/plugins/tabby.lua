return {
  "nanozuki/tabby.nvim",
  event = "VeryLazy",
  config = function()
    local theme = {
      fill = 'TabLineFill',
      head = 'TabLine',
      current_tab = 'DotfilesTabActive',
      tab = 'DotfilesTabInactive',
    }
    local first = 1
    local anchor
    local previous_order = {}
    local labels = {}
    local pending_scroll
    local browsing = false
    local previous_tab
    local last_visible
    local tab_names = require('tabby.feature.tab_name')

    local function shorten(text, width)
      if vim.fn.strdisplaywidth(text) <= width then return text end
      local ellipsis_width = vim.fn.strdisplaywidth('…')
      if width < ellipsis_width then return '' end
      local chars = vim.fn.split(text, '\\zs')
      -- Paths keep their filename/extension; other labels keep both ends.
      local left_budget = text:find('[/\\]') and 0 or math.ceil((width - ellipsis_width) * 0.6)
      local left, right = '', ''
      local first_right = 1
      for i, char in ipairs(chars) do
        if vim.fn.strdisplaywidth(left .. char) > left_budget then break end
        left = left .. char
        first_right = i + 1
      end
      for i = #chars, first_right, -1 do
        if vim.fn.strdisplaywidth(left .. '…' .. chars[i] .. right) > width then break end
        right = chars[i] .. right
      end
      return left .. '…' .. right
    end

    local function page(delta, whole_page)
      pending_scroll = { delta = delta, whole_page = whole_page }
      browsing = true
      vim.cmd('redrawtabline')
    end

    -- Native statusline callbacks also work for the overflow markers.
    _G.DotfilesTablineScroll = function(direction, _, button)
      if button == 'l' then page(direction == 1 and -1 or 1) end
    end

    local group = vim.api.nvim_create_augroup('DotfilesTabline', { clear = true })
    local function highlights()
      local active = vim.api.nvim_get_hl(0, { name = 'TabLineSel', link = false })
      active.bold = true
      active.underline = false
      vim.api.nvim_set_hl(0, theme.current_tab, active)
      local inactive = vim.api.nvim_get_hl(0, { name = 'TabLine', link = false })
      inactive.bold = false
      inactive.underline = false
      vim.api.nvim_set_hl(0, theme.tab, inactive)
    end
    highlights()
    vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlights })
    local redraw_pending = false
    vim.api.nvim_create_autocmd({ 'BufModifiedSet', 'BufWritePost', 'WinNew', 'WinClosed' }, {
      group = group,
      callback = function()
        if redraw_pending then return end
        redraw_pending = true
        vim.schedule(function()
          redraw_pending = false
          vim.cmd('redrawtabline')
        end)
      end,
    })
    vim.api.nvim_create_autocmd('TabEnter', {
      group = group,
      callback = function() browsing = false end,
    })
    vim.api.nvim_create_autocmd('User', {
      group = group,
      pattern = 'DotfilesTabPicked',
      callback = function() browsing = false end,
    })

    for key, delta in pairs({ ScrollWheelUp = -1, ScrollWheelDown = 1, ScrollWheelLeft = -1, ScrollWheelRight = 1 }) do
      local code = '<' .. key .. '>'
      vim.keymap.set({ 'n', 'i', 'x', 't' }, code, function()
        local shown = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
        if shown and vim.fn.getmousepos().screenrow == 1 then
          vim.schedule(function() page(delta) end)
          return '<Ignore>'
        end
        return code
      end, { expr = true, desc = 'Scroll tabline with ' .. key })
    end

    require('tabby.tabline').set(function(line)
      local tabs = line.tabs().tabs
      local total = #tabs
      local head = { { '  ', hl = theme.head }, line.sep('', theme.head, theme.fill) }
      if total == 0 then return { head, hl = theme.fill } end

      local current = 1
      local positions = {}
      for i, tab in ipairs(tabs) do
        positions[tab.id] = i
        if tab.is_current() then current = i end
      end
      if previous_tab ~= tabs[current].id then browsing = false end
      previous_tab = tabs[current].id
      if anchor and not positions[anchor] then
        -- If the leftmost tab closed, keep its next surviving neighbor in view.
        for i = first + 1, #previous_order do
          if positions[previous_order[i]] then
            anchor = previous_order[i]
            break
          end
        end
      end
      first = positions[anchor] or math.max(1, math.min(first, total))

      local markers, marker_widths = {}, { [0] = 0 }
      local function marker(count, left)
        if count == 0 then return { '', hl = theme.tab } end
        local key = (left and 'left' or 'right') .. count
        if markers[key] then return markers[key] end
        local text = left and ('‹ ' .. count .. ' ') or (' ' .. count .. ' ›')
        local direction = left and 1 or 2
        markers[key] = {
          '%' .. direction .. '@v:lua.DotfilesTablineScroll@' .. text .. '%X',
          hl = theme.tab,
        }
        return markers[key]
      end

      local function marker_width(count)
        if not marker_widths[count] then
          marker_widths[count] = vim.fn.strdisplaywidth('‹ ' .. count .. ' ')
        end
        return marker_widths[count]
      end

      -- Reserve a stable footer width while browsing so its digits/arrows cannot
      -- change which tabs fit. Narrow layouts use a shorter position indicator.
      local footer_width = 0
      local full_footer = vim.o.columns >= 70
      if browsing and total > 1 then
        local sample = full_footer and (' tabs ' .. total .. '–' .. total .. '/' .. total .. ' · ←active ' .. total .. ' ')
          or (' ' .. total .. '/' .. total .. ' ←' .. total .. ' ')
        footer_width = vim.fn.strdisplaywidth(sample)
        if vim.o.columns - footer_width < 8 then footer_width = 0 end
      end
      -- These are literal display cells; click/highlight escapes add no width.
      local budget = vim.o.columns - vim.fn.strdisplaywidth('  ') - footer_width
      -- Reserve enough room for either marker even when both sides overflow.
      local tab_budget = budget - 2 * marker_width(total)
      local compact = tab_budget < 16
      if compact then
        -- Keep the workspace name even when decoration no longer fits.
        head = { '', hl = theme.head }
        budget = vim.o.columns - footer_width
        tab_budget = budget
      end

      local nodes, widths = {}, {}
      local next_labels = {}
      local decoration_width = vim.fn.strdisplaywidth('   ')
      for i, tab in ipairs(tabs) do
        local hl = tab.is_current() and theme.current_tab or theme.tab
        local number = tostring(tab.number())
        local prefix = number .. ' '
        local windows, modified = 0, false
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab.id)) do
          if vim.api.nvim_win_get_config(win).relative == '' then
            windows = windows + 1
            modified = modified or vim.bo[vim.api.nvim_win_get_buf(win)].modified
          end
        end
        local count = windows > 1 and (' ×' .. windows) or ''
        local close_width = vim.fn.strdisplaywidth('')
        -- Multi-window tabs share a right-aligned count/close area. Keep the
        -- total width stable when focus reveals the active tab's close button.
        local count_before = count
        local close = tab.is_current() and tab.close_btn('') or string.rep(' ', close_width)
        if not tab.is_current() and count ~= '' then
          count_before = string.rep(' ', close_width + 1)
          close = count:sub(2)
        end
        -- Reserve the modified and close slots to prevent movement on edit/focus.
        local status = modified and ' ●' or string.rep(' ', vim.fn.strdisplaywidth(' ●'))
        if compact and vim.fn.strdisplaywidth(prefix .. count .. status) + 2 > tab_budget then count = '' end
        if compact and vim.fn.strdisplaywidth(prefix .. count .. status) + 1 > tab_budget then status = '' end
        local suffix = status .. count
        local overhead = vim.fn.strdisplaywidth(prefix .. suffix) + (compact and 0 or decoration_width)
        local limit = math.max(0, math.min(24, tab_budget - overhead))
        local name = tab.name():gsub('[%c]', ' ')
        if tab_names.get_raw(tab.id) == '' then
          -- Replace Tabby's fallback [N+] suffix with our explicit window count.
          name = name:gsub('%[%d+%+%]$', '')
        end
        local cached = labels[tab.id]
        if not cached or cached.name ~= name or cached.limit ~= limit then
          local text = shorten(name, limit)
          cached = { name = name, limit = limit, text = text:gsub('%%', '%%%%'), width = vim.fn.strdisplaywidth(text) }
        end
        next_labels[tab.id] = cached
        widths[i] = overhead + cached.width
        if compact then
          nodes[i] = { prefix .. cached.text .. suffix, hl = hl, click = { 'to_tab', tab.id } }
        else
          local tail = { status, count_before, ' ', close, ' ' }
          local padding = 1 -- The space after the tab number.
          for i, part in ipairs(tail) do
            if type(part) ~= 'string' then break end
            local spaces = part:match('^ *')
            padding = padding + #spaces
            tail[i] = part:sub(#spaces + 1)
            if tail[i] ~= '' then break end
          end
          -- Share unused indicator/close-slot spacing around the filename.
          -- Move only padding: the right-side controls and total width stay put.
          local left_padding = math.floor(padding / 2)
          local node = {
            line.sep('', hl, theme.fill),
            ' ' .. number .. string.rep(' ', left_padding),
            cached.text,
            string.rep(' ', padding - left_padding),
            tail,
            line.sep('', hl, theme.fill),
            hl = hl,
            click = { 'to_tab', tab.id },
          }
          nodes[i] = node
        end
      end
      labels = next_labels

      local fits = {}
      local function fit(start)
        if compact then return start end
        if fits[start] then return fits[start] end
        local used = marker_width(start - 1)
        local last = start - 1
        for i = start, total do
          local needed = used + widths[i] + marker_width(total - i)
          if needed > budget then break end
          used = used + widths[i]
          last = i
        end
        fits[start] = last
        return last
      end

      if pending_scroll then
        local scroll = pending_scroll
        pending_scroll = nil
        if scroll.whole_page and scroll.delta > 0 then
          first = math.min(total, (positions[last_visible] or fit(first)) + 1)
        elseif scroll.whole_page then
          local target = math.max(1, first - 1)
          first = target
          while first > 1 and fit(first - 1) >= target do first = first - 1 end
        else
          first = math.max(1, math.min(total, first + scroll.delta))
        end
      end
      if not browsing then first = math.min(first, current) end
      local last = fit(first)
      if not browsing then
        -- Move the left edge until the selected tab fits; never trim it away.
        while last < current do
          first = first + 1
          last = fit(first)
        end
      end
      -- Clamp scrolling to the last full viewport, also after closing/resizing.
      while first > 1 and fit(first - 1) == total do
        first = first - 1
        last = total
      end
      anchor = tabs[first].id
      last_visible = tabs[last].id
      previous_order = {}
      for i, tab in ipairs(tabs) do previous_order[i] = tab.id end

      local out = { head }
      if not compact then out[#out + 1] = marker(first - 1, true) end
      for i = first, last do out[#out + 1] = nodes[i] end
      if not compact then out[#out + 1] = marker(total - last, false) end
      if footer_width > 0 then
        local direction = current < first and '←' or (current > last and '→' or '')
        local position = full_footer and (' tabs ' .. first .. '–' .. last .. '/' .. total)
          or (' ' .. first .. '/' .. total)
        if direction ~= '' then
          position = position .. (full_footer and ' · ' .. direction .. 'active ' or ' ' .. direction) .. current
        end
        out[#out + 1] = line.spacer()
        out[#out + 1] = { position .. ' ', hl = theme.tab }
      end
      out.hl = theme.fill
      return out
    end)

    vim.keymap.set('n', '<leader>t[', function() page(-1) end, { desc = 'Scroll tabline left' })
    vim.keymap.set('n', '<leader>t]', function() page(1) end, { desc = 'Scroll tabline right' })
    vim.keymap.set('n', '<leader>t{', function() page(-1, true) end, { desc = 'Page tabline left' })
    vim.keymap.set('n', '<leader>t}', function() page(1, true) end, { desc = 'Page tabline right' })
    vim.keymap.set('n', '<leader>tt', function() require('utils.tab_picker').open() end, { desc = 'Find tab' })
  end,
}
