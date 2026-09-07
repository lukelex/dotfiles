return {
  "nanozuki/tabby.nvim",
  event = "VeryLazy",
  config = function()
    local theme = {
      fill = 'TabLineFill',
      head = 'TabLine',
      current_tab = 'TabLineSel',
      tab = 'TabLine',
      win = 'TabLine',
      tail = 'TabLine',
    }

    local offset = 0
    local api = require('tabby.module.api')

    local function render_tab(line, tab)
      local hl = tab.is_current() and theme.current_tab or theme.tab
      return {
        line.sep('', hl, theme.fill),
        tab.number(),
        '/',
        tab.name(),
        tab.close_btn(''),
        line.sep('', hl, theme.fill),
        hl = hl,
        margin = ' ',
        click = { 'to_tab', tab.id },
      }
    end

    local function measure_node(node)
      if type(node) == 'string' then
        return vim.fn.strdisplaywidth(node)
      elseif type(node) == 'table' then
        local w = 0
        for i, child in ipairs(node) do
          w = w + measure_node(child)
          if i == 1 and node.margin and type(node.margin) == 'string' then
            w = w + vim.fn.strdisplaywidth(node.margin)
          end
        end
        return w
      end
      return 0
    end

    local function measure(nodes)
      local w = 0
      for _, node in ipairs(nodes) do
        w = w + measure_node(node)
      end
      return w
    end

    local function clamp_offset(max_offset)
      offset = math.max(0, math.min(offset, max_offset))
    end

    require('tabby.tabline').set(function(line)
      local tabs = line.tabs().tabs
      local total = #tabs
      local width = vim.o.columns

      local head = { { '  ', hl = theme.head }, line.sep('', theme.head, theme.fill) }
      local head_w = measure(head)

      if total == 0 then
        return { head, hl = theme.fill }
      end

      -- Current tab index (0-based) within the tab list.
      local current_idx = 0
      local current = api.get_current_tab()
      for i, tab in ipairs(tabs) do
        if tab.id == current then
          current_idx = i - 1
          break
        end
      end

      -- Estimate the visible window capacity using the current tab's width,
      -- then position the window so the current tab stays in view.
      local pivot_w = math.max(1, measure_node(render_tab(line, tabs[current_idx + 1])))
      local cap = math.max(1, math.floor((width - head_w - 2) / pivot_w))

      local start = offset
      -- Recenter the window on the current tab whenever it's out of view.
      local end_idx = math.min(start + cap - 1, total - 1)
      if current_idx > end_idx then
        start = current_idx - (end_idx - start)
      elseif current_idx < start then
        start = current_idx
      end
      start = math.max(0, math.min(start, math.max(0, total - 1)))
      end_idx = math.min(start + cap - 1, total - 1)
      offset = start

      local rendered = {}
      for i = start, end_idx do
        rendered[#rendered + 1] = render_tab(line, tabs[i + 1])
      end

      -- Drop trailing tabs until the slice actually fits (names may be wider
      -- than the estimate). Trimming from the right never drops the current
      -- tab because it sits inside the window, not at the trailing edge.
      local budget = width - head_w
      local leading = start > 0 and 1 or 0
      local trailing = end_idx < total - 1 and 1 or 0
      budget = budget - leading - trailing

      while #rendered > 0 and measure(rendered) + trailing > budget do
        table.remove(rendered)
        end_idx = end_idx - 1
        trailing = end_idx < total - 1 and 1 or 0
      end
      if #rendered == 0 then
        rendered = { render_tab(line, tabs[start + 1]) }
        end_idx = start
      end

      local out = { head }
      if leading == 1 then
        out[#out + 1] = { '‹', hl = theme.tab }
      end
      for _, node in ipairs(rendered) do
        out[#out + 1] = node
      end
      if trailing == 1 then
        out[#out + 1] = { '›', hl = theme.tab }
      end

      out.hl = theme.fill
      return out
    end)

    local function page(delta)
      local total = #api.get_tabs()
      local max = math.max(total - 1, 0)
      offset = offset + delta
      clamp_offset(max)
      vim.cmd('redrawtabline')
    end

    vim.keymap.set('n', '<leader>t[', function() page(-1) end, { desc = 'Scroll tabline left' })
    vim.keymap.set('n', '<leader>t]', function() page(1) end, { desc = 'Scroll tabline right' })
  end
}
