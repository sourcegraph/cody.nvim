local dataFolder = vim.fn.stdpath("data") .. "/llmsp"
vim.fn.mkdir(dataFolder, "p")
local tosAccepted = vim.fn.filereadable(dataFolder .. "/tos-accepted") == 1

if not tosAccepted then
  local choice = vim.fn.input(
        "By using Cody, you agree to its license and privacy statement: https://about.sourcegraph.com/terms/cody-notice . Do you wish to proceed? Yes/No: ")
      :lower()
  if choice == "yes" or choice == "y" then
    local file = io.open(dataFolder .. "/tos-accepted", "w")
    if file ~= nil then
      file:write("")
      file:close()
      tosAccepted = true
    end
  end
end

if tosAccepted then
  local version = "0.1"
  local binaryName = string.format("llmsp-%s-%s-%s", version,
    vim.fn.system("uname -m"), vim.fn.system("uname"):lower())
  binaryName = binaryName:gsub("\n", "") -- remove any newlines present from the vim.fn.system calls
  local binaryPath = vim.fn.stdpath("data") .. "/llmsp/" .. binaryName
  if vim.fn.executable(binaryPath) ~= 1 then
    print("LLMSP binary not found. Downloading latest release.\n" .. binaryName .. "\n" .. binaryPath)
    vim.fn.system({
      "curl", "-L",
      "https://github.com/pjlast/llmsp/releases/download/v0.1-beta/" .. binaryName,
      "--create-dirs", "-o",
      binaryPath
    })
    vim.fn.system({ "chmod", "+x", binaryPath })
    print("Done!")
  end

  local bufnr = 0
  local winnr = 0
  local fileType = ""
  if vim.fn.executable(binaryPath) == 1 then
    vim.api.nvim_create_autocmd({ "FileType" }, {
      pattern = "*",
      callback = function()
        vim.lsp.start {
          name = "cody",
          cmd = { "llmsp" }, -- TODO: Replace with the downloaded binary
          root_dir = vim.fs.dirname(vim.fs.find({ '.git' }, { upward = true })[1]),
          trace = "off",
          handlers = {
            ["cody/chat"] = function(err, result, ctx, config)
              if bufnr == 0 and winnr == 0 then
                bufnr, winnr = vim.lsp.util.open_floating_preview(result.message, fileType, {
                  height = #result.message,
                  width = 80,
                  focus_id = "codyResponse",
                  border = "rounded",
                  title = result.prompt
                })
                vim.lsp.util.open_floating_preview(result.message, fileType, {
                  height = #result.message,
                  width = 80,
                  focus_id = "codyResponse",
                  border = "rounded",
                  title = result.prompt
                })
                vim.cmd('set ma')
              end

              vim.api.nvim_win_set_height(winnr, #result.message)
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.message)
              vim.api.nvim_buf_set_option(bufnr, 'filetype', fileType)
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

  if vim.fn.executable(binaryPath) == 1 then
    vim.api.nvim_create_user_command("CodyReplace", function(command)
      local p = "file://" .. vim.fn.expand('%:p')

      for _, client in pairs(vim.lsp.get_active_clients({ name = "cody" })) do
        client.request("workspace/executeCommand", {
          command = "cody",
          arguments = { p, command.line1 - 1, command.line2 - 1, command.args, true, true }
        }, function()
        end, 0)
      end
    end, { range = 2, nargs = 1 })

    vim.api.nvim_create_user_command("CodyCode", function(command)
      local p = "file://" .. vim.fn.expand('%:p')

      for _, client in pairs(vim.lsp.get_active_clients({ name = "cody" })) do
        client.request("workspace/executeCommand", {
          command = "cody",
          arguments = { p, command.line1 - 1, command.line2 - 1, command.args, false, true }
        }, function()
        end, 0)
      end
    end, { range = 2, nargs = 1 })

    vim.api.nvim_create_user_command("CodyExplain", function(command)
      local p = "file://" .. vim.fn.expand('%:p')

      for _, client in pairs(vim.lsp.get_active_clients({ name = "cody" })) do
        if bufnr == 0 and winnr == 0 then
          bufnr, winnr = vim.lsp.util.open_floating_preview({ "" }, "plaintext", {
            height = 1,
            width = 80,
            focus_id = "codyResponse",
            border = "rounded",
            title = command.args
          })
          vim.lsp.util.open_floating_preview({ "" }, "plaintext", {
            height = 1,
            width = 80,
            focus_id = "codyResponse",
            border = "rounded",
            title = command.args
          })
          vim.cmd('set ma')
          vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
            buffer = bufnr,
            callback = function()
              bufnr = 0
              winnr = 0
            end
          })
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Cody is thinking..." })
        client.request("workspace/executeCommand", {
          command = "cody.explain",
          arguments = { p, command.line1 - 1, command.line2 - 1, command.args, false }
        }, function(_, result, _, _)
          -- Update the text
          -- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.message)

          -- Update the height
          -- vim.api.nvim_win_set_height(winnr, #result.message)
        end, 0)
      end
    end, { range = 2, nargs = 1 })

    vim.api.nvim_create_user_command("CodyDiff", function(command)
      local p = "file://" .. vim.fn.expand('%:p')
      local buf = vim.api.nvim_get_current_buf()
      local orig = vim.api.nvim_buf_get_lines(buf, command.line1 - 1, command.line2, false)
      fileType = vim.api.nvim_buf_get_option(buf, 'filetype')

      for _, client in pairs(vim.lsp.get_active_clients({ name = "cody" })) do
        if bufnr == 0 and winnr == 0 then
          bufnr, winnr = vim.lsp.util.open_floating_preview({ "" }, "markdown", {
            height = 1,
            width = 80,
            focus_id = "codyResponse",
            border = "rounded",
            title = command.args
          })
          vim.lsp.util.open_floating_preview({ "" }, "markdown", {
            height = 1,
            width = 80,
            focus_id = "codyResponse",
            border = "rounded",
            title = command.args
          })
          vim.cmd('set ma')
          vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
            buffer = bufnr,
            callback = function()
              bufnr = 0
              winnr = 0
            end
          })
          vim.keymap.set('n', '<cr>', function()
            local start_line = command.line1 - 1
            local end_line = command.line2
            vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))

            vim.cmd("bdelete")
          end, { silent = true, buffer = bufnr })
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Cody is thinking..." })
        client.request("workspace/executeCommand", {
          command = "cody.explain",
          arguments = { p, command.line1 - 1, command.line2 - 1, command.args,
            true }
        }, function(_, result, _, _)
        end, 0)
      end
    end, { range = 2, nargs = 1 })
  end
end
