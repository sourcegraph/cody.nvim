if vim.fn.executable "llmsp" == 1 then
  vim.api.nvim_create_user_command("CodyReplace", function(command)
    local p = "file://" .. vim.fn.expand('%:p')

    for _, client in pairs(vim.lsp.get_active_clients({ name = "llmsp" })) do
      client.request("workspace/executeCommand", {
        command = "cody",
        arguments = { p, command.line1 - 1, command.line2 - 1, command.args, true, true }
      }, function()
      end, 0)
    end
  end, { range = 2, nargs = 1 })

  vim.api.nvim_create_user_command("CodyCode", function(command)
    local p = "file://" .. vim.fn.expand('%:p')

    for _, client in pairs(vim.lsp.get_active_clients({ name = "llmsp" })) do
      client.request("workspace/executeCommand", {
        command = "cody",
        arguments = { p, command.line1 - 1, command.line2 - 1, command.args, false, true }
      }, function()
      end, 0)
    end
  end, { range = 2, nargs = 1 })

  vim.api.nvim_create_user_command("CodyExplain", function(command)
    local p = "file://" .. vim.fn.expand('%:p')

    for _, client in pairs(vim.lsp.get_active_clients({ name = "llmsp" })) do
      client.request("workspace/executeCommand", {
        command = "cody.explain",
        arguments = { p, command.line1 - 1, command.line2 - 1, command.args, false }
      }, function(_, result, _, _)
        vim.lsp.util.open_floating_preview(result.message, "markdown", {
          height = #result.message,
          width = 80,
          focus_id = "codyResponse",
          border = "rounded",
          title = "Cody explain"
        })
        -- Call it again so that it focuses the window immediately
        vim.lsp.util.open_floating_preview(result.message, "markdown", {
          height = #result.message,
          width = 80,
          focus_id = "codyResponse",
          border = "rounded",
          title = "Cody explain"
        })
      end, 0)
    end
  end, { range = 2, nargs = 1 })

  vim.api.nvim_create_user_command("CodyDiff", function(command)
    local p = "file://" .. vim.fn.expand('%:p')
    local buf = vim.api.nvim_get_current_buf()
    local orig = vim.api.nvim_buf_get_lines(buf, command.line1 - 1, command.line2, false)

    for _, client in pairs(vim.lsp.get_active_clients({ name = "llmsp" })) do
      client.request("workspace/executeCommand", {
        command = "cody.explain",
        arguments = { p, command.line1 - 1, command.line2 - 1, command.args,
          true }
      }, function(_, result, _, _)
        vim.lsp.util.open_floating_preview(result.message, "markdown", {
          height = #result.message - 2,
          width = 80,
          focus_id = "codyResponse",
          border = "rounded",
          title = "Cody diff"
        })
        -- Call it again so that it focuses the window immediately
        local bufnr, _ = vim.lsp.util.open_floating_preview(result.message,
          "markdown", {
            height = #result.message - 2,
            width = 80,
            focus_id = "codyResponse",
            border = "rounded",
            title = "Cody diff"
          })
        vim.cmd('set ma')
        local new = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local diff = vim.diff(table.concat(orig, "\n"), table.concat(new, "\n"), {
          linematch = true,
          result_type = "indices",
          ignore_whitespace = true,
          ignore_whitespace_change = true,
          ignore_whitespace_change_at_eol = true,
          ignore_cr_at_eol = true,
          ignore_blank_lines = true,
        })

        for _, v in pairs(diff) do
          for i = v[3], v[3] + v[4] - 1 do
            vim.api.nvim_buf_add_highlight(bufnr, -1, "DiffAdd", i - 1, 0, -1)
          end
        end

        vim.keymap.set('n', '<cr>', function()
          local start_line = command.line1 - 1
          local end_line = command.line2
          vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, new)

          vim.cmd("bdelete")
        end, { silent = true, buffer = bufnr })
      end, 0)
    end
  end, { range = 2, nargs = 1 })
end
