local config = require("todo.config")
local utils = require("todo.utils")

local M = {}

local todo_path = vim.fn.stdpath("data") .. "/todo.json"
local lookup_path = vim.fn.stdpath("data") .. "/todo_lookups.json"

local function read(path)
    local file = io.open(path, "r")
    if not file then return {} end
    local content = file:read("*a")
    file:close()
    return vim.fn.json_decode(content) or {}
end

local function write(path, data)
    local file = io.open(path, "w")
    if file then
        file:write(vim.fn.json_encode(data))
        file:close()
    end
end

function M.add()
    vim.ui.input({ prompt = "New TODO: " }, function(input)
        if input and input ~= "" then
            local list_name, text = utils.get_list_name(input)
            if list_name == nil then
                print("Please provide a list name.")
                return
            end
            local lists = read(lookup_path)
            local todos = read(todo_path)
            if lists[list_name] == nil then
                lists[list_name] = true
                todos[list_name] = {}
                write(lookup_path, lists)
            end
            table.insert(todos[list_name], { text = text, done = false })
            write(todo_path, todos)
            print("TODO added to " .. list_name .. ": " .. text)
        end
    end)
end

local todo = function(lists, list_name, todos)
    local low_pending = 1

    if config.options.sort_pending then
        for i, val in ipairs(todos) do
            if val.done then
                local x = todos[low_pending]
                todos[low_pending] = todos[i]
                todos[i] = x
                low_pending = low_pending + 1
            end
        end
    end

    local extmark_cache = {}

    local buf, win = utils.create_buffer()

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
            lists[list_name] = new_todos
            write(todo_path, lists)
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
            local all_extmarks = vim.api.nvim_buf_get_extmarks(bufr, ns_id, {0, 0}, {-1, -1}, {details = false})

            if next(extmarks) ~= nil and (#extmarks ~= 1 or (#extmarks == 1 and extmarks[1][1] == all_extmarks[#all_extmarks][1])) then
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

    vim.keymap.set("n", config.options.keys.toggle_pending, function()
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

function M.list()
    local todos = read(todo_path)

    if next(todos) == nil then
        print("No TODOs found.")
        return
    end

    local keys = {}
    for list, _ in pairs(todos) do
        table.insert(keys, list)
    end

    table.sort(keys)

    local buf, win  = utils.create_buffer()
    local iter_count = 1

    for _, list in ipairs(keys)  do
        vim.api.nvim_buf_set_lines(buf, iter_count - 1, iter_count - 1, false, { list })
        iter_count = iter_count + 1
    end

    vim.keymap.set("n", config.options.keys.enter_list, function()
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        local line_num = cursor_pos[1]

        local list_name = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]

        if todos[list_name] then
            todo(todos, list_name, todos[list_name])
        else
            print("List with name " .. list_name .. " does not exist. If you have edited the name, please save and reopen the window.")
        end

    end,{ buffer = buf, nowait = true, noremap = true, silent = true })

    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = buf,
        callback = function()
            local buffer_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local lines = {}
            for _, line in ipairs(buffer_lines) do
                line = line:match("^%s*(.-)%s*$")
                if line:match("^%S*$") then
                    table.insert(lines, line)
                end
            end

            local count = 0
            for _, _ in pairs(todos) do
                count = count + 1
            end

            if count == #lines - 1 then
                local lists = read(lookup_path)
                local i = 1
                for _, key in ipairs(keys) do
                    if key ~= lines[i] and lines[i] ~= "" then
                        lists[lines[i]] = true
                        todos[lines[i]] = todos[key]
                        lists[key] = nil
                        todos[key] = nil
                    end
                    if lines[i] == "" then
                        lists[key] = nil
                        todos[key] = nil
                    end
                    i = i + 1
                end
                for key, _ in pairs(todos) do
                    if next(todos[key]) == nil then
                        lists[key] = nil
                        todos[key] = nil
                    end
                end
                write(todo_path, todos)
                write(lookup_path, lists)
            end
        end
    })

    vim.keymap.set("n", config.options.keys.close, function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, nowait = true, noremap = true, silent = true })
end

vim.api.nvim_set_keymap("n", config.options.keys.add, "<CMD>lua require('todo').add()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", config.options.keys.list, "<CMD>lua require('todo').list()<CR>", { noremap = true, silent = true })

return M
