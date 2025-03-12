local M = {}

local config = require("todo.config")
local core = require("todo.core")

M.add = core.add
M.list = core.list
M.options = config.options

M.setup = function(opts)
    M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M

