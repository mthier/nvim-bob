local core = require("nvim-bob.core")

local M = {}

function M.setup(opts)
    opts = opts or {}
	core.configure(opts)
end

function M.init(prefix, path)
    return core.init(prefix, path)
end

function M.clean()
    return core.clean()
end

function M.dev(bang, args)
    return core.dev(bang, args)
end

function M.project(bang, ...)
    return core.project(bang, ...)
end

function M.goto(bang, do_all, args)
    return core.goto_source(bang, do_all, args)
end

function M.graph()
    return core.graph()
end

function M.status(...)
    return core.status(...)
end

function M.search(bang, pattern)
    return core.search(bang, pattern)
end

return M
