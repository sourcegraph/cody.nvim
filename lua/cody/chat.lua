local M = {}

M.chat_buffer = vim.api.nvim_create_buf(false, true)
M.input_buffer = vim.api.nvim_create_buf(false, true)
M.hover_buffer = vim.api.nvim_create_buf(false, true)
M.client = nil -- Client used for LSP requests. Needs to be initialized.
M.chat_history = {}

vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(0, true) end, { silent = true, buffer = M.hover_buffer })

vim.keymap.set('n', '<cr>', function()
    M.hover_return_callback(vim.api.nvim_buf_get_lines(0, 0, -1, false))
    vim.api.nvim_win_close(0, true)
end, { silent = true, buffer = M.hover_buffer })

local close_chat = function()
    if vim.api.nvim_win_is_valid(M.chat_window) and (vim.api.nvim_win_is_valid(M.input_window)) then
        vim.api.nvim_win_close(M.chat_window, true)
        vim.api.nvim_win_close(M.input_window, true)
    end
end

vim.keymap.set('n', 'q', close_chat, { silent = true, buffer = M.input_buffer })
vim.keymap.set('n', 'q', close_chat, { silent = true, buffer = M.chat_buffer })

vim.api.nvim_create_autocmd({ "WinEnter" }, {
    callback = function()
        if M.chat_window ~= nil and M.input_window ~= nil then
            local winnr = vim.api.nvim_get_current_win()
            if (winnr ~= M.chat_window) and (winnr ~= M.input_window) then
                close_chat()
            end
        end
    end
})
vim.api.nvim_buf_set_option(M.chat_buffer, 'filetype', 'markdown')
vim.api.nvim_buf_set_option(M.input_buffer, 'filetype', 'markdown')

vim.keymap.set('n', 'k', function()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    if cursor_pos[1] == 1 then
        vim.api.nvim_set_current_win(M.chat_window)
    else
        vim.api.nvim_win_set_cursor(0, { cursor_pos[1] - 1, cursor_pos[2] })
    end
end, { silent = true, buffer = M.input_buffer })

vim.keymap.set('n', 'j', function()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    if cursor_pos[1] == vim.api.nvim_buf_line_count(M.chat_buffer) then
        vim.api.nvim_set_current_win(M.input_window)
    else
        vim.api.nvim_win_set_cursor(0, { cursor_pos[1] + 1, cursor_pos[2] })
    end
end, { silent = true, buffer = M.chat_buffer })

-- Register "send chat" command for the input buffer.
-- Pressing enter, while in normal mode, will send the chat message.
vim.keymap.set('n', '<cr>', function()
    -- Append your message to the chat history.
    local lines = vim.api.nvim_buf_get_lines(M.input_buffer, 0, -1, false)
    table.insert(M.chat_history, "# You:")
    for _, line in pairs(lines) do
        table.insert(M.chat_history, line)
    end
    table.insert(M.chat_history, "")

    -- Set the chat buffer contents for instant feedback and clear the
    -- input buffer.
    vim.api.nvim_buf_set_lines(M.chat_buffer, 0, -1, false, M.chat_history)
    vim.api.nvim_buf_set_lines(M.input_buffer, 0, -1, false, {})

    -- Send the request to get a response from Cody.
    M.client.request("workspace/executeCommand", {
            command = "cody.chat/message",
            arguments = {
                table.concat(lines, "\n")
            },
        },
        function(_, codyResult, _, _)
            table.insert(M.chat_history, "# Cody:")
            for _, resp_line in pairs(vim.split(codyResult.message, "\n")) do
                table.insert(M.chat_history, resp_line)
            end
            table.insert(M.chat_history, "")
            vim.api.nvim_buf_set_lines(M.chat_buffer, 0, -1, false, M.chat_history)
            vim.api.nvim_win_set_cursor(M.chat_window, { #M.chat_history, 0 })
        end, 0)
end, { silent = true, buffer = M.input_buffer })

M.open_chat = function()
    local ui = vim.api.nvim_list_uis()[1]
    local cody_chat_height = math.floor(ui.height / 2)
    local chat_input_offset = cody_chat_height + math.floor(ui.height / 2) / 2

    M.client.request("workspace/executeCommand", {
            command = "cody.chat/history",
        },
        function(_, result, _, _)
            M.chat_history = {}
            if result ~= nil then
                for _, msg in pairs(result) do
                    if msg.speaker == "HUMAN" then
                        table.insert(M.chat_history, "# You:")
                    else
                        table.insert(M.chat_history, "# Cody:")
                    end

                    for _, msgLine in pairs(vim.split(msg.text, "\n")) do
                        table.insert(M.chat_history, msgLine)
                    end
                    table.insert(M.chat_history, "")
                end
            end
            vim.api.nvim_buf_set_lines(M.chat_buffer, 0, -1, false, M.chat_history)

            M.chat_window = vim.api.nvim_open_win(M.chat_buffer, false, {
                width = math.floor(ui.width / 2),
                height = cody_chat_height,
                relative = "editor",
                row = math.floor((ui.height / 2) / 2) - 3,
                col = math.floor((ui.width / 2) / 2),
                border = "rounded",
                title = "Cody chat"
            })

            M.input_window = vim.api.nvim_open_win(M.input_buffer, true, {
                width = math.floor(ui.width / 2),
                height = 3,
                relative = "editor",
                row = chat_input_offset - 1,
                col = math.floor((ui.width / 2) / 2),
                border = "rounded",
                title = "Input"
            })

            if #M.chat_history > 0 then
                vim.api.nvim_win_set_cursor(M.chat_window, { #M.chat_history, 0 })
            end
        end, 0
    )
end

M.open_hover = function(window_title, buffer_lang, callback)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    M.hover_window = vim.api.nvim_open_win(M.hover_buffer, true, {
        width = 80,
        height = 1,
        relative = 'win',
        row = cursor_pos[1] - 1 - vim.fn.winsaveview().topline,
        col = cursor_pos[2],
        border = "rounded",
        title = window_title,
        title_pos = 'center'
    })

    vim.api.nvim_buf_set_option(M.hover_buffer, 'filetype', buffer_lang)
    vim.api.nvim_win_set_buf(M.hover_window, M.hover_buffer)
    vim.cmd("setlocal norelativenumber")
    vim.cmd("setlocal nonumber")
    M.hover_return_callback = callback
end

return M
