if vim.g.loaded_nvim_bob then
    return
end
vim.g.loaded_nvim_bob = true

local bob = require("nvim-bob")

vim.api.nvim_create_user_command("BobInit", function(opts)
    local fargs = opts.fargs or {}
    bob.init(fargs[1], fargs[2])
end, {
    nargs = "*",
    complete = function(arglead, cmdline, cursorpos)
        local args = vim.split(vim.trim(cmdline), "%s+")
        if #args <= 2 then
            local ok, items = pcall(function()
                return require("nvim-bob.core").prefix_complete(arglead)
            end)
            return (ok and type(items) == "table") and items or {}
        end
        return {}
    end,
})

vim.api.nvim_create_user_command("BobClean", function()
    bob.clean()
end, {})

vim.api.nvim_create_user_command("BobDev", function(opts)
    bob.dev(opts.bang, opts.fargs)
end, { nargs = "*", bang = true })

vim.api.nvim_create_user_command("BobProject", function(opts)
    local fargs = opts.fargs or {}

    if #fargs >= 1 then
        bob.project(opts.bang, unpack(fargs))
    else
        bob.project(opts.bang)
    end
end, {
    nargs = "*",
    bang = true,
    complete = function(arglead, cmdline, cursorpos)
        local ok, items = pcall(function()
            return require("nvim-bob.core").package_and_config_complete(
                arglead,
                cmdline,
                cursorpos
            )
        end)
        if ok and type(items) == "table" then
            return items
        end
        return {}
    end,
})

vim.api.nvim_create_user_command("BobGoto", function(opts)
    local bang = opts.bang and 1 or 0
    local fargs = opts.fargs or {}

    bob.goto(bang, false, fargs)
end, {
    nargs = "*",
    bang = true,
    complete = function(arglead, cmdline, cursorpos)
        local ok, items = pcall(function()
            return require("nvim-bob.core").project_package_complete(
                arglead,
                cmdline,
                cursorpos
            )
        end)
        if ok and type(items) == "table" then
            return items
        end
        return {}
    end,
})

vim.api.nvim_create_user_command("BobGraph", function()
    bob.graph()
end, {})

vim.api.nvim_create_user_command("BobStatus", function(opts)
    bob.status(unpack(opts.fargs))
end, { nargs = "*" })

vim.api.nvim_create_user_command("BobSearch", function(opts)
    bob.search(opts.bang, opts.args)
end, { nargs = "?", bang = true })
