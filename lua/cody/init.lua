local M = {}

local chat = require("cody.chat")

M.setup = function(opts)
  vim.api.nvim_create_user_command("CodyChat", function()
    chat.open_chat()
  end, { range = 2 })

  vim.api.nvim_create_user_command("CodyExplain", function(command)
    local p = "file://" .. vim.fn.expand('%:p')

    local current_buf = vim.api.nvim_get_current_buf()

    chat.open_hover(command.args, 'markdown', function(hover_content)
      local start_line = command.line1 - 1
      local end_line = command.line2
      vim.api.nvim_buf_set_lines(current_buf, start_line, end_line, false, hover_content)
    end)

    for _, client in pairs(vim.lsp.get_active_clients({ name = "cody" })) do
      vim.api.nvim_buf_set_lines(require("cody.chat").hover_buffer, 0, -1, false, { "Cody is thinking..." })
      client.request("workspace/executeCommand", {
        command = "cody.explain",
        arguments = { p, command.line1 - 1, command.line2 - 1, command.args, false }
      }, function(_, _, _, _)
      end, 0)
    end
  end, { range = 2, nargs = 1 })

  vim.api.nvim_create_user_command("CodyDiff", function(command)
    local p = "file://" .. vim.fn.expand('%:p')

    local current_buf = vim.api.nvim_get_current_buf()

    chat.open_hover(command.args, vim.api.nvim_buf_get_option(0, 'filetype'), function(hover_content)
      local start_line = command.line1 - 1
      local end_line = command.line2
      vim.api.nvim_buf_set_lines(current_buf, start_line, end_line, false, hover_content)
    end)

    for _, client in pairs(vim.lsp.get_active_clients({ name = "cody" })) do
      vim.api.nvim_buf_set_lines(require("cody.chat").hover_buffer, 0, -1, false, { "Cody is thinking..." })
      client.request("workspace/executeCommand", {
        command = "cody.explain",
        arguments = { p, command.line1 - 1, command.line2 - 1, command.args, true }
      }, function(_, _, _, _)
      end, 0)
    end
  end, { range = 2, nargs = 1 })

  vim.api.nvim_create_autocmd({ "FileType" }, {
    pattern = "*",
    callback = function()
      vim.lsp.start {
        name = "cody",
        cmd = { "llmsp" }, -- TODO: Replace with the downloaded binary
        root_dir = vim.fs.dirname(vim.fs.find({ '.git' }, { upward = true })[1]),
        trace = "off",
        handlers = {
          ["cody/chat"] = function(_, result, _, _)
            if vim.api.nvim_win_is_valid(chat.hover_window) then
              vim.api.nvim_win_set_height(chat.hover_window, #result.message)
            end
            vim.api.nvim_buf_set_lines(chat.hover_buffer, 0, -1, false, result.message)
            vim.api.nvim_buf_set_option(chat.hover_buffer, 'filetype', vim.api.nvim_buf_get_option(0, 'filetype'))
          end
        },
        settings = {
          llmsp = {
            sourcegraph = {
              url = "https://sourcegraph.sourcegraph.com",
              accessToken = "",
              autoComplete = "off",
              repos = { "github.com/sourcegraph/sourcegraph" }
            },
          },
        },
      }
    end,
  })
end

return M
