local M = {}
local ns = vim.api.nvim_create_namespace("ruby_hover_signature")

function M.ruby()
  local source = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)

  vim.lsp.buf_request_all(source, "textDocument/hover", function(client)
    return vim.lsp.util.make_position_params(nil, client.offset_encoding)
  end, function(results)
    if not vim.api.nvim_buf_is_valid(source)
        or vim.api.nvim_get_current_buf() ~= source
        or not vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor) then
      return
    end

    local lines = {}
    for client_id, response in pairs(results) do
      local result = response.result
      if result and result.contents then
        local content = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        if #content > 0 then
          if #lines > 0 then
            lines[#lines + 1] = "---"
          end
          local client = vim.lsp.get_client_by_id(client_id)
          if client and vim.tbl_count(results) > 1 then
            lines[#lines + 1] = "# " .. client.name
          end
          vim.list_extend(lines, content)
        end
      end
    end

    if #lines == 0 then
      vim.notify("No information available", vim.log.levels.INFO)
      return
    end

    local class, method = lines[1]:match("^([%w_:]+)#([%w_!?=]+)$")
    if class then
      -- Class#method is Ruby documentation notation: Ruby parses #method as a comment.
      -- Mark the signature up separately while Tree-sitter renders the Markdown below it.
      lines[1] = "```ruby"
      table.insert(lines, 2, class .. "#" .. method)
      table.insert(lines, 3, "```")
    end

    local buffer = vim.lsp.util.open_floating_preview(lines, "markdown", {
      focus_id = "textDocument/hover",
    })
    if class then
      vim.api.nvim_buf_set_extmark(buffer, ns, 1, 0, {
        end_col = #class,
        hl_group = "@type.ruby",
        priority = 200,
      })
      vim.api.nvim_buf_set_extmark(buffer, ns, 1, #class + 1, {
        end_col = #class + 1 + #method,
        hl_group = "@function.method.ruby",
        priority = 200,
      })
    end
  end)
end

return M
