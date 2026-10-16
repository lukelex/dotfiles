return {
  "nanozuki/tabby.nvim",
  event = "VeryLazy",
  config = function()
    local theme = {
      fill = 'TabLineFill',
      head = 'TabLine',
      current_tab = 'TabLineSel',
      tab = 'TabLine',
    }
    local first = 1
    local anchor
    local previous_order = {}
    local labels = {}
    local pending_scroll
    local browsing = false
    local previous_tab

    local function shorten(text, width)
      if vim.fn.strdisplaywidth(text) <= width then return text end
      if width <= 0 then return '' end
      local result = ''
      for _, char in ipairs(vim.fn.split(text, '\\zs')) do
        if vim.fn.strdisplaywidth(result .. char .. '…') > width then break end
        result = result .. char
      end
      return result .. '…'
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
    vim.api.nvim_create_autocmd('TabEnter', {
      group = group,
      callback = function() browsing = false end,
    })
    vim.api.nvim_create_autocmd('User', {
      group = group,
      pattern = 'DotfilesTabPicked',
      callback = function() browsing = false end,
    })

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

      -- These are literal display cells; click/highlight escapes add no width.
      local budget = vim.o.columns - vim.fn.strdisplaywidth('  ')
      -- Reserve enough room for either marker even when both sides overflow.
      local tab_budget = budget - 2 * marker_width(total)
      local compact = tab_budget < 12
      if compact then
        -- Keep the workspace name even when decoration no longer fits.
        head = { '', hl = theme.head }
        budget = vim.o.columns
        tab_budget = budget
      end

      local nodes, widths = {}, {}
      local next_labels = {}
      local decoration_width = vim.fn.strdisplaywidth('   ')
      for i, tab in ipairs(tabs) do
        local hl = tab.is_current() and theme.current_tab or theme.tab
        local number = tostring(tab.number())
        local prefix = number .. '/'
        local overhead = vim.fn.strdisplaywidth(prefix) + (compact and 0 or decoration_width)
        local limit = math.max(0, math.min(24, tab_budget - overhead))
        local name = tab.name():gsub('[%c]', ' ')
        local cached = labels[tab.id]
        if not cached or cached.name ~= name or cached.limit ~= limit then
          local text = shorten(name, limit)
          cached = { name = name, limit = limit, text = text:gsub('%%', '%%%%'), width = vim.fn.strdisplaywidth(text) }
        end
        next_labels[tab.id] = cached
        widths[i] = overhead + cached.width
        if compact then
          nodes[i] = { prefix .. cached.text, hl = hl, click = { 'to_tab', tab.id } }
        else
          local node = {
            line.sep('', hl, theme.fill),
            ' ' .. prefix,
            cached.text,
            ' ',
            tab.close_btn(''),
            ' ',
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
          first = math.min(total, fit(first) + 1)
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
      previous_order = {}
      for i, tab in ipairs(tabs) do previous_order[i] = tab.id end

      local out = { head }
      if not compact then out[#out + 1] = marker(first - 1, true) end
      for i = first, last do out[#out + 1] = nodes[i] end
      if not compact then out[#out + 1] = marker(total - last, false) end
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
