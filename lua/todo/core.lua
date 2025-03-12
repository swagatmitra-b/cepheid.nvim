local config = require("todo.config")

local M = {}

local path = vim.fn.stdpath("data") .. "/todo_list.json"

local function read_todos()
    local file = io.open(path, "r")
    if not file then return {} end
    local content = file:read("*a")
    file:close()
    return vim.fn.json_decode(content) or {}
end

local function write_todos(todos)
    local file = io.open(path, "w")
    if file then
        file:write(vim.fn.json_encode(todos))
        file:close()
    end
end

function M.add()
    vim.ui.input({ prompt = "New TODO: " }, function(input)
        if input and input ~= "" then
            local todos = read_todos()
            table.insert(todos, { text = input, done = false })
            write_todos(todos)
            print("TODO added: " .. input)
        end
    end)
end

function M.list()
    local todos = read_todos()
    local extmark_cache = {}

    if #todos == 0 then
        print("No TODOs found.")
        return
    end

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

    local ns_id = vim.api.nvim_create_namespace("immutable_text")

    for i, todo in ipairs(todos)  do
        local virt_text = {}

        if todo.done then
            virt_text = { "[Completed] ", "String" }
        else
            virt_text = { "[Pending]   ", "ErrorMsg" }
        end

        vim.api.nvim_buf_set_lines(buf, i - 1, i - 1, false, { todo.text })
        vim.api.nvim_buf_set_extmark(buf, ns_id, i - 1, 0, {
            virt_text = { virt_text },
            virt_text_pos = "inline",
        })
    end

    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = buf,
        callback = function()
            local buffer_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local lines = {}
            for _, line in ipairs(buffer_lines) do
                if line:match("%S") then
                    table.insert(lines, line)
                end
            end
            local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {details = true})

            local new_todos = {}
            for i, todo in ipairs(lines) do
                local extmark = extmarks[i]
                if extmark then
                    local virt = extmark[4].virt_text[1][1]
                    local set_todo = {}
                    if virt == "[Pending]   " then
                        set_todo = { done = false, text = todo }
                    else
                        set_todo = { done = true, text = todo }
                    end
                    table.insert(new_todos, set_todo)
                else
                    table.insert(new_todos, {done = false, text = todo})
                end
            end
            write_todos(new_todos)
        end
    })

    local function on_lines(_, bufr, _, firstline, lastline, new_lastline, _)
        local lines = vim.api.nvim_buf_get_lines(bufr, 0, -1, false)

        for i = firstline, new_lastline - 1 do
            if lines[i + 1] == "" or lines[i + 1]:match("^%s*$") then
                vim.api.nvim_buf_clear_namespace(bufr, ns_id, i, i + 1)
            end
        end

        if lastline > new_lastline then
            local extmarks = vim.api.nvim_buf_get_extmarks(bufr, ns_id, {firstline, 0}, {lastline - 1, 0}, {details = true})

            if next(extmarks) ~= nil and #extmarks ~= 1 then
                local even_half = #extmarks / 2
                local odd_half = math.ceil(#extmarks / 2)

                local line_diff = lastline - new_lastline

                if #extmarks % 2 == 0 then
                    for i = 1, even_half + math.abs(even_half - line_diff) do
                        local id = extmarks[i]
                        if id then
                            vim.api.nvim_buf_del_extmark(bufr, ns_id, id[1])
                        end
                    end
                else
                    for i = 1, odd_half + math.abs(odd_half - line_diff) do
                        local id = extmarks[i]
                        if id then
                            vim.api.nvim_buf_del_extmark(bufr, ns_id, id[1])
                        end
                    end
                end
            end
        end

    end
    vim.api.nvim_buf_attach(buf, false, { on_lines = on_lines })

    vim.keymap.set("n", config.options.keys.close, function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, nowait = true, noremap = true, silent = true })

    vim.keymap.set("n", config.options.keys.toggle_complete, function()
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        local line_num = cursor_pos[1]

        local virt_toggle = {}
        local extmark = {}

        if extmark_cache[line_num] then
            extmark = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, extmark_cache[line_num], {details = true})
        else
            extmark = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, line_num, {details = true})
        end

        if extmark[3].virt_text[1][1] == "[Pending]   " then
            virt_toggle = { "[Completed] ", "String"}
        else
            virt_toggle = { "[Pending]   ", "ErrorMsg"}
        end

        if extmark_cache[line_num] then
            vim.api.nvim_buf_del_extmark(buf, ns_id, extmark_cache[line_num])
        else
            vim.api.nvim_buf_del_extmark(buf, ns_id, line_num)
        end

        local ext_id = vim.api.nvim_buf_set_extmark(buf, ns_id, line_num - 1, 0, {
            virt_text = { virt_toggle },
            virt_text_pos = "inline",
        })

        extmark_cache[line_num] = ext_id

    end,{buffer=buf,nowait=true,noremap=true,silent=true})
end

vim.api.nvim_set_keymap("n", config.options.keys.add, "<CMD>lua require('todo').add()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", config.options.keys.list, "<CMD>lua require('todo').list()<CR>", { noremap = true, silent = true })

return M
