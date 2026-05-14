-- Headless integration test (native bob).
-- Run: nvim --headless -l test/test_native.lua
vim.opt.rtp:prepend(vim.fn.getcwd())

local ok, err = pcall(function()
    require("nvim-bob").setup({ bob_config_path = "configurations" })
    require("nvim-bob.core").init(nil, vim.fn.getcwd() .. "/test")
    require("nvim-bob.core").project(false, "app_a", "native", "-DBUILD_TYPE=Release", "--destination", "dist_folder")

    local ccdb = vim.fn.getcwd() .. "/test/dev/compile_commands.json"
    assert(
        vim.fn.filereadable(ccdb) == 1,
        "compile_commands.json not generated: " .. ccdb
    )
end)

if not ok then
    io.stderr:write("FAIL: " .. tostring(err) .. "\n")
    os.exit(1)
end

print("PASS")
os.exit(0)
