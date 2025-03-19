local M = {}

M.options = {
    sort_pending = false,
    window = {
        width = 0.5,
        height = 0.35,
        border = "rounded"
    },
    keys = {
        add = "<A-i>",
        list = "<A-l>",
        toggle_pending = "<leader>d",
        close = "q",
        enter_list = "<leader>d"
    }
}

return M


