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
    local path_sep = vim.loop.os_uname().version:match "Windows" and "\\" or "/"
    local dataFolder = vim.fn.stdpath("data") .. path_sep .. "llmsp" .. path_sep
    vim.fn.mkdir(dataFolder, "p")
    local tosAccepted = vim.fn.filereadable(dataFolder .. "tos-accepted") == 1

    if not tosAccepted then
        local choice = vim.fn.input(
                "By using Cody, you agree to its license and privacy statement: https://about.sourcegraph.com/terms/cody-notice . Do you wish to proceed? Yes/No: ")
            :lower()
        if choice == "yes" or choice == "y" then
            local file = io.open(dataFolder .. "tos-accepted", "w")
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

    local os_name = vim.loop.os_uname().sysname:lower()
    local arch = vim.loop.os_uname().machine:lower()
    if arch == "amd64" or arch == "x86_64" then
        arch = "amd64"
    elseif arch == "arm64" then
        arch = "arm64"
    end
    if os_name == "windows" then
        os_name = "windows.exe"
    end

    local binary_name = "llmsp-v0.1.0-beta.1-" .. arch .. "-" .. os_name
    local binary_path = dataFolder .. binary_name
    if not opts.dev then
        if vim.fn.filereadable(binary_path) ~= 1 then
            print("\nDownloading llmsp binary for Cody")
            local binary_url = "https://github.com/pjlast/llmsp/releases/download/v0.1.0-beta.1/" .. binary_name

            vim.fn.system({
                "curl", "-L", binary_url, "-o", binary_path
            })
            vim.fn.system({
                "chmod", "+x", binary_path
            })
        end
    else
        binary_path = "llmsp"
    end

    local anonymousUidFile = dataFolder .. "sourcegraphAnonymousUid"

    vim.api.nvim_create_user_command("CodyChat", function()
        chat.open_chat("file://" .. vim.fn.expand('%:p'))
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

    vim.api.nvim_create_user_command("CodyHover", function(command)
        local current_buf = vim.api.nvim_get_current_buf()
        chat.open_hover(command.args, '', function(hover_content)
            local start_line = command.line1 - 1
            local end_line = command.line2
            vim.api.nvim_buf_set_lines(current_buf, start_line, end_line, false, hover_content)
        end)
        vim.api.nvim_win_set_height(chat.hover_window, #vim.api.nvim_buf_get_lines(chat.hover_buffer, 0, -1, false))
    end, { range = 2 })

    -- Create LSP Client
    local client_id = vim.lsp.start({
        name = "cody",
        cmd = { binary_path },
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
                    repos = opts.repos,
                    uidFile = anonymousUidFile
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
