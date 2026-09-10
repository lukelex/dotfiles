return {
  {
    "olimorris/codecompanion.nvim",

    version = "^19.0.0",
    enabled = true,
    event = { "BufRead" },

    cmd = {
      "CodeCompanion",
      "CodeCompanionActions",
      "CodeCompanionChat",
      "CodeCompanionCmd",
    },

    keys = {
      {
        "<leader>aa",
        "<cmd>CodeCompanionActions<cr>",
        mode = { "n", "v" },
        desc = "AI actions",
      },
      {
        "<leader>ac",
        "<cmd>CodeCompanionChat Toggle<cr>",
        mode = { "n", "v" },
        desc = "AI chat",
      },
      {
        "<leader>an",
        "<cmd>CodeCompanionChat<cr>",
        mode = { "n", "v" },
        desc = "AI new chat",
      },
      {
        "<leader>as",
        "<cmd>CodeCompanionChat Add<cr>",
        mode = "v",
        desc = "AI add selection to chat",
      },
      {
        "<leader>ai",
        ":CodeCompanion ",
        mode = { "n", "v" },
        desc = "AI inline prompt",
      },
      {
        "<leader>ae",
        "<cmd>CodeCompanion /explain<cr>",
        mode = "v",
        desc = "AI explain selection",
      },
      {
        "<leader>at",
        "<cmd>CodeCompanion /tests<cr>",
        mode = "v",
        desc = "AI generate tests",
      },
    },

    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",

      {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "codecompanion" },
        opts = {},
      },
    },

    init = function()
      -- Allows:
      --   :cc refactor this method
      vim.cmd([[cabbrev cc CodeCompanion]])

      local namespace = vim.api.nvim_create_namespace("codecompanion-inline-progress")
      local progress = {}

      local frames = {
        "⠋",
        "⠙",
        "⠹",
        "⠸",
        "⠼",
        "⠴",
        "⠦",
        "⠧",
        "⠇",
        "⠏",
      }

      local function stop(bufnr)
        local state = progress[bufnr]

        if not state then
          return
        end

        state.timer:stop()

        if not state.timer:is_closing() then
          state.timer:close()
        end

        if vim.api.nvim_buf_is_valid(bufnr) then
          local position =
              vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, state.mark, {})

          if #position > 0 then
            vim.api.nvim_buf_set_extmark(
              bufnr,
              namespace,
              position[1],
              position[2],
              {
                id = state.mark,
                virt_text = {
                  { " ✓ CodeCompanion finished", "DiagnosticOk" },
                },
                virt_text_pos = "eol",
              }
            )

            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(bufnr) then
                pcall(
                  vim.api.nvim_buf_del_extmark,
                  bufnr,
                  namespace,
                  state.mark
                )
              end
            end, 1000)
          end
        end

        progress[bufnr] = nil
      end

      local function start(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        -- Clean up a previous request if necessary.
        if progress[bufnr] then
          stop(bufnr)
        end

        local row = 0
        local win = vim.fn.bufwinid(bufnr)

        if win ~= -1 then
          row = vim.api.nvim_win_get_cursor(win)[1] - 1
        end

        local mark = vim.api.nvim_buf_set_extmark(
          bufnr,
          namespace,
          row,
          0,
          {
            virt_text = {
              { " " .. frames[1] .. " CodeCompanion…", "DiagnosticInfo" },
            },
            virt_text_pos = "eol",
          }
        )

        local timer = vim.uv.new_timer()

        local state = {
          timer = timer,
          mark = mark,
          frame = 1,
        }

        progress[bufnr] = state

        timer:start(
          100,
          100,
          vim.schedule_wrap(function()
            -- Request may have completed while this callback was queued.
            if progress[bufnr] ~= state then
              return
            end

            if not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end

            local position =
                vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, mark, {})

            if #position == 0 then
              return
            end

            state.frame = (state.frame % #frames) + 1

            vim.api.nvim_buf_set_extmark(
              bufnr,
              namespace,
              position[1],
              position[2],
              {
                id = mark,
                virt_text = {
                  {
                    " " .. frames[state.frame] .. " CodeCompanion…",
                    "DiagnosticInfo",
                  },
                },
                virt_text_pos = "eol",
              }
            )
          end)
        )
      end

      local group = vim.api.nvim_create_augroup(
        "CodeCompanionInlineProgress",
        { clear = true }
      )

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = {
          "CodeCompanionInlineStarted",
          "CodeCompanionInlineFinished",
        },

        callback = function(event)
          if event.match == "CodeCompanionInlineStarted" then
            start(event.buf)
          elseif event.match == "CodeCompanionInlineFinished" then
            stop(event.buf)
          end
        end,
      })
    end,

    opts = {
      adapters = {
        http = {
          gemini = function()
            return require("codecompanion.adapters").extend("gemini", {
              env = {
                api_key = "GEMINI_API_KEY",
              },

              schema = {
                model = {
                  -- This model currently has a Gemini API free tier.
                  default = "gemini-3-flash-preview",
                },
              },
            })
          end,

          opts = {
            -- Hide unrelated preset adapters from the adapter picker.
            show_presets = false,

            -- Allow selecting another Gemini model when needed.
            show_model_choices = true,
          },
        },
      },

      interactions = {
        chat = {
          adapter = {
            name = "gemini",
            model = "gemini-3-flash-preview",
          },
        },

        inline = {
          adapter = {
            name = "gemini",
            model = "gemini-3-flash-preview",
          },

          keymaps = {
            accept_change = {
              modes = { n = "gda" },
              description = "Accept AI change",
            },
            reject_change = {
              modes = { n = "gdr" },
              description = "Reject AI change",
            },
          },
        },

        cmd = {
          adapter = {
            name = "gemini",
            model = "gemini-3-flash-preview",
          },
        },

        background = {
          adapter = {
            name = "gemini",
            model = "gemini-3-flash-preview",
          },
        },
      },

      display = {
        action_palette = {
          -- LazyVim already includes Snacks.
          provider = "snacks",
        },

        chat = {
          window = {
            layout = "vertical",
            position = "right",
            width = 0.40,
          },
        },

        inline = {
          layout = "vertical",
        },
      },

      rules = {
        default = {
          description = "Project-specific development instructions",

          files = {
            "AGENTS.md",
            "AGENT.md",
            ".github/copilot-instructions.md",
          },
        },

        opts = {
          chat = {
            enabled = true,
            autoload = "default",

            -- Also include project rules when using prompt-library entries
            -- such as /explain and /tests.
            autoload_groups_in_prompt_library = true,
          },
        },
      },

      opts = {
        log_level = "ERROR",
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",

    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      vim.list_extend(opts.ensure_installed, {
        "markdown",
        "markdown_inline",
        "yaml",
      })
    end,
  },
}
