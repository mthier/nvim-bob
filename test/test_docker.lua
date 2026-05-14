-- Headless integration test (bob via docker prefix).
-- Run: nvim --headless -l test/test_docker.lua
vim.opt.rtp:prepend(vim.fn.getcwd())

local docker_prefix = 'docker run --rm -v "$(pwd):$(pwd)" -w "$(pwd)" --user $(id -u):$(id -g) nvim-bob-test'

local ok, err = pcall(function()
    require("nvim-bob").setup({
        bob_config_path = "configurations",
        bob_prefix_list = { ["ci-docker"] = docker_prefix },
    })
    require("nvim-bob.core").init("ci-docker", vim.fn.getcwd() .. "/test")

    -- Remove state files created by the native bob ls check inside init() so
    -- the container bob dev starts without host-path contamination.
    for _, f in ipairs(vim.fn.glob(vim.fn.getcwd() .. "/test/.bob-*", false, true)) do
        vim.fn.delete(f)
    end

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
