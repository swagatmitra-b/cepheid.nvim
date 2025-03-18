local config = require("todo.config")

local M = {}

function M.create_buffer()
    local width = math.floor(vim.o.columns * config.options.window.width)
    local height = math.floor(vim.o.lines * config.options.window.height)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = config.options.window.border
    })

    vim.api.nvim_buf_set_option(buf, "relativenumber", false)
    vim.api.nvim_buf_set_option(buf, "number", true)

    vim.api.nvim_create_autocmd({"InsertEnter","InsertLeave"},{
        buffer = buf,
        callback = function()
            vim.api.nvim_win_set_option(win, "relativenumber", false)
            vim.api.nvim_win_set_option(win, "number", true)
        end,
    })

    return buf, win
end

function M.get_list_name(input)
    local list_match = string.gmatch(input, "%-%-(%a+)")
    local word_match = string.gmatch(input, "%S+")
    local list_name = {}
    local text = {}
    for value in list_match do
        table.insert(list_name, value)
    end
    for word in word_match do
        table.insert(text, word)
    end

    if #list_name ~= 0 then
        table.remove(text, #text)
    end

    -- TODO: fallback to last exited list if nil

    return list_name[#list_name], table.concat(text, " ")
end

return M
