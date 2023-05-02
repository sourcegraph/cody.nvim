local M = {}

local chat = require("cody.chat")

-- Used for debugging
function Dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. Dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

M.setup = function(opts)
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

    if not tosAccepted then
        return
    end

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

        vim.api.nvim_buf_set_lines(require("cody.chat").hover_buffer, 0, -1, false, { "Cody is thinking..." })
        chat.client.request("workspace/executeCommand", {
            command = "cody.explain",
            arguments = { p, command.line1 - 1, command.line2 - 1, command.args, false },
        }, function(_, _, _, _)
        end, 0)
    end, { range = 2, nargs = 1 })

    vim.api.nvim_create_user_command("CodyTest", function(command)
        for _, client in pairs(vim.lsp.get_active_clients({ name = "cody" })) do
            local workDoneToken = "1234"
            local autocmd_id = vim.api.nvim_create_autocmd({ "User" }, {
                pattern = { "LspProgressUpdate" },
                callback = function()
                    print(Dump(client.messages.progress[workDoneToken]))
                end,
            })

            client.request("workspace/executeCommand", {
                command = "testCommand",
                workDoneToken = workDoneToken
            }, function(_, _, _, _)
            end, 0)
        end
    end, { range = 2 })

    vim.api.nvim_create_user_command("CodyDiff", function(command)
        local p = "file://" .. vim.fn.expand('%:p')

        local current_buf = vim.api.nvim_get_current_buf()

        chat.open_hover(command.args, vim.api.nvim_buf_get_option(0, 'filetype'), function(hover_content)
            local start_line = command.line1 - 1
            local end_line = command.line2
            vim.api.nvim_buf_set_lines(current_buf, start_line, end_line, false, hover_content)
        end)

        vim.api.nvim_buf_set_lines(require("cody.chat").hover_buffer, 0, -1, false, { "Cody is thinking..." })
        chat.client.request("workspace/executeCommand", {
            command = "cody.explain",
            arguments = { p, command.line1 - 1, command.line2 - 1, command.args, true }
        }, function(_, _, _, _)
        end, 0)
    end, { range = 2, nargs = 1 })

    -- Create LSP Client
    local client_id = vim.lsp.start({
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
            end,
        },
        settings = {
            llmsp = {
                sourcegraph = {
                    url = opts.url,
                    accessToken = opts.accessToken,
                    autoComplete = opts.autoComplete,
                    repos = opts.repos
                },
            },
        },
    })

    vim.api.nvim_create_autocmd({ "FileType" }, {
        pattern = "*",
        callback = function()
            vim.lsp.buf_attach_client(0, client_id)
        end,
    })

    chat.client = vim.lsp.get_client_by_id(client_id)
end

return M
