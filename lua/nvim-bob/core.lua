local state = require("nvim-bob.state")
local cfg = require("nvim-bob.config")

local M = {}

-- Strip Bob's INFO/WARNING/See-lines from command output so only recipe
-- output remains.
function M.remove_info(text)
    text = text:gsub("INFO:.-\n", "")
    text = text:gsub("WARNING:.-\n", "")
    text = text:gsub("See .-\n", "")
    return text
end

-- Escape pipe characters so the string is safe to embed in makeprg.
function M.escape_for_makeprg(text)
    if not text then
        return ""
    end
    return text:gsub("|", "\\|")
end

-- Completion handler: returns names from the configured prefix
-- map filtered by arg_lead.
function M.prefix_complete(arg_lead)
    local names = vim.tbl_keys(cfg.bob_prefix_list or {})
    table.sort(names)
    local result = {}
    for _, name in ipairs(names) do
        if vim.startswith(name, arg_lead) then
            table.insert(result, name)
        end
    end
    return result
end

-- Completion handler: returns all known top-level package names.
function M.package_complete(arg_lead, cmd_line, cursor_pos)
    return state.bob_package_list
end

-- Completion handler for BobGoto: returns reduced package names
-- from the last BobProject run, or falls back to tree completion
-- if no project is loaded.
function M.project_package_complete(arg_lead, cmd_line, cursor_pos)
    M.check_init()

    if state.project_package_src_dirs_reduced then
        local keys = vim.tbl_keys(state.project_package_src_dirs_reduced)
        table.sort(keys)
        return keys
    end

    return M.package_tree_complete(arg_lead, cmd_line, cursor_pos)
end

-- Completion handler: filters the package tree list by the current
-- argument prefix.
function M.package_tree_complete(arg_lead, cmd_line, cursor_pos)
    local result = {}
    local pattern = "^" .. vim.pesc(arg_lead) .. "[^/]*$"

    for _, elem in ipairs(state.bob_package_tree_list or {}) do
        if elem:match(pattern) then
            table.insert(result, elem)
        end
    end

    return result
end

-- Initialize the plugin at the given path (defaults to cwd).
-- Runs `bob ls` to discover packages and populates state.
-- Must be called before any other command.
function M.init(prefix, path)
    state.reset()

    if prefix and prefix ~= "" then
        vim.g.bob_prefix = (cfg.bob_prefix_list or {})[prefix] or prefix
    end

    -- Use cwd when no path is given.
    local base = (path == "" or path == nil) and vim.fn.getcwd()
        or vim.fn.fnamemodify(path, ":p")

    -- Not using `--directory` but `cwd` instead, because when running inside of
    -- a container via `g:bob_prefix` we would pass the path on the host to Bob
    -- running in the container, where the path is very likely different
    local check = vim.system({ "bob", "ls" }, { cwd = base, text = true })
        :wait()

    if check.code ~= 0 then
        local msg = string.format(
            "Couldn't get Bob package list: %s",
            vim.trim(check.stdout or "")
        )
        vim.notify(msg, vim.log.levels.ERROR)
        error(msg)
    end

    -- Run again with the prefix to enumerate packages inside a container or
    -- special environment.
    local bob_prefix = vim.g.bob_prefix or ""
    local ls_result
    if bob_prefix == "" then
        ls_result = vim.system({ "bob", "ls" }, { cwd = base, text = true })
            :wait()
    else
        ls_result = vim.system(
            { "bash", "-c", bob_prefix .. " bob ls" },
            { cwd = base, text = true }
        ):wait()
    end

    if ls_result.code ~= 0 then
        local msg = string.format(
            "Couldn't get Bob package list: %s",
            vim.trim(ls_result.stdout or "")
        )
        vim.notify(msg, vim.log.levels.ERROR)
        error(msg)
    end

    local packages = M.remove_info(ls_result.stdout or "")
    packages = vim.split(packages, "\n", { plain = true, trimempty = true })

    state.bob_base_path = base
    state.bob_package_list = packages
    state.bob_package_tree_list = packages
    state.bob_config_path = cfg.bob_config_path or ""
    state.bob_config_path_abs = state.bob_config_path ~= ""
            and vim.fs.joinpath(base, state.bob_config_path)
        or ""

    -- Discover available config names from YAML files in the config directory.
    if state.bob_config_path_abs ~= "" then
        local yaml_files =
            vim.fn.globpath(state.bob_config_path_abs, "*.yaml", false, true)

        state.config_names = vim.tbl_map(function(p)
            return vim.fn.fnamemodify(p, ":t:r")
        end, yaml_files)
    else
        state.config_names = {}
    end

    state.is_initialized = true

    vim.notify("BobInit successful!", vim.log.levels.INFO)
end

-- Raises an error if the plugin has not been initialized via M.init().
function M.check_init()
    if not state.is_initialized then
        local msg = "nvim-bob not initialized!"
        vim.notify(msg, vim.log.levels.ERROR)
        error(msg)
    end
end

-- Completion handler for BobProject: returns packages for arg 1,
-- configs for arg 2, and extra build options for all subsequent args.
function M.package_and_config_complete(arglead, cmdline, cursorpos)
    -- cmdline begins with the command name, so arg positions are
    -- 1-based from index 2.
    local fargs = vim.split(cmdline, "%s+", { trimempty = true })
    local nfargs = #fargs

    local packages = state.bob_package_list or {}
    local configs = state.config_names or {}
    local auto_completions = cfg.bob_auto_complete_items or {}

    if nfargs < 2 then
        return packages
    elseif nfargs < 3 then
        return configs
    else
        return auto_completions
    end
end

-- Delete the dev/build and dev/dist directories under the bob base path.
function M.clean()
    M.check_init()
    vim.fn.delete(state.bob_base_path .. "/dev/build", "rf")
    vim.fn.delete(state.bob_base_path .. "/dev/dist", "rf")
end

-- Build the given package with `bob dev`, then set up project mode
-- (src/build dirs, compile_commands.json). Bang controls whether :make jumps
-- to the first error.
function M.project(bang, package, ...)
    M.check_init()

    local args = {}
    local varargs = { ... }

    if #varargs > 0 then
        -- First extra argument is always the configuration name
        -- (without the '-c').
        args.config = varargs[1]
        if #varargs > 1 then
            args.args = { unpack(varargs, 2) }
        end
    end

    local ok = pcall(function()
        local cmd = M.build_cmd(
            package,
            vim.tbl_extend("force", { use_prefix = true }, args)
        )
        M.run_make(bang, cmd)
    end)

    if not ok then
        vim.notify(
            "Running Bob failed. Not all features of nvim-bob's project mode might be available."
                .. " Re-run :BobProject as soon as these errors are fixed.",
            vim.log.levels.WARN
        )
        return
    end

    M.project_impl(package, args)
end

-- Build and return the bob dev command string for the given package and args.
-- Does not set makeprg — the caller passes the result to run_make().
function M.build_cmd(package, args)
    args = args or {}

    local bob_prefix = vim.g.bob_prefix or ""
    local cmd = string.format("cd %s;", vim.fn.shellescape(state.bob_base_path))

    if args.use_prefix and bob_prefix ~= "" then
        cmd = cmd .. " " .. M.escape_for_makeprg(bob_prefix)
    end

    cmd = cmd .. " bob dev " .. package

    if args.config then
        cmd = cmd
            .. string.format(
                " -c %s/%s",
                state.bob_config_path or "",
                args.config
            )
    end

    if args.args and #args.args > 0 then
        cmd = cmd .. " " .. table.concat(args.args, " ")
    end

    return cmd
end

-- Set makeprg to cmd and run :make, populating the quickfix list with build errors.
-- bang controls whether Neovim jumps to the first error after the build.
-- Patches shellpipe to preserve the exit code when output is piped through tee.
function M.run_make(bang, cmd)
    -- makeprg is set here so the data flow is explicit: build_cmd produces the
    -- command, run_make consumes it. vim's :make always reads makeprg implicitly.
    vim.o.makeprg = cmd

    -- The default "2>&1| tee" discards PIPESTATUS, causing :make to miss build
    -- failures. Patching it ensures the correct exit code propagates.
    local original_shellpipe = vim.o.shellpipe
    if original_shellpipe == "2>&1| tee" then
        vim.o.shellpipe = "2>&1| tee %s;exit ${PIPESTATUS[0]}"
    end

    local ok, err = pcall(vim.cmd.make, { bang = bang })

    vim.o.shellpipe = original_shellpipe

    if not ok or vim.v.shell_error ~= 0 then
        local msg = string.format("Bob build failed: %s", tostring(err))
        vim.notify(msg, vim.log.levels.ERROR)
        error(msg)
    end
end

-- Change directory into a package's source directory. With no args, cd to the
-- bob base path. bang uses global `cd`; without bang uses window-local `lcd`.
function M.goto_source(bang, do_all, args)
    M.check_init()

    local cd_command = bang and "cd" or "lcd"

    -- No arguments: cd to the bob base directory.
    if #args == 0 then
        vim.cmd(cd_command .. " " .. state.bob_base_path)
        return
    end

    -- Exactly one argument: cd to that package's source directory.
    if #args == 1 then
        local package_name = args[1]
        local dir

        if not do_all and state.project_package_src_dirs_reduced then
            -- Use cached source directories from the last BobProject run.
            dir = state.project_package_src_dirs_reduced[package_name]
        else
            -- Query bob for the source directory.
            local result = vim.system(
                { "bob", "query-path", "-f", "{src}", package_name },
                { cwd = state.bob_base_path, text = true }
            ):wait()

            if result.code ~= 0 then
                vim.notify(
                    string.format(
                        "bob query-path failed: %s",
                        vim.trim(result.stdout or "")
                    ),
                    vim.log.levels.ERROR
                )
                return
            end

            dir = M.remove_info(result.stdout or "")

            if dir == nil or dir == "" then
                vim.notify(
                    "package has no sources or is not checked out",
                    vim.log.levels.WARN
                )
                return
            end
        end

        if dir == nil or dir == "" then
            vim.notify(
                string.format(
                    "package %s has no source directory",
                    package_name
                ),
                vim.log.levels.ERROR
            )
            return
        end

        vim.cmd(string.format("%s %s/%s", cd_command, state.bob_base_path, dir))
        return
    end

    -- More than one argument is not supported.
    vim.notify("BobGoto takes at most one parameter", vim.log.levels.ERROR)
end

-- Generate a dependency graph for the current project and open it. Requires
-- a prior :BobProject call. Supports "dot" (PNG via graphviz) and "d3" (HTML).
function M.graph()
    M.check_init()

    if not state.project_name or state.project_name == "" then
        local msg = "No project loaded. Run :BobProject before :BobGraph."
        vim.notify(msg, vim.log.levels.ERROR)
        error(msg)
    end

    local graph_type = cfg.bob_graph_type
    local filename = state.project_name:gsub("[_:-]", "")

    local cmd = { "bob", "graph" }

    if state.project_config and state.project_config ~= "" then
        for part in string.gmatch(state.project_config, "%S+") do
            table.insert(cmd, part)
        end
    end

    for _, opt in ipairs(state.project_query_options or {}) do
        table.insert(cmd, opt)
    end

    vim.list_extend(
        cmd,
        { "-t", graph_type, "-f", filename, state.project_name }
    )

    local result = vim.system(cmd, { cwd = state.bob_base_path, text = true })
        :wait()

    if result.code ~= 0 then
        vim.notify(
            string.format(
                "error running bob graph:\n%s",
                result.stderr or result.stdout or ""
            ),
            vim.log.levels.ERROR
        )
        return
    end

    vim.notify(result.stdout, vim.log.levels.INFO)

    local graph_dir = state.bob_base_path .. "/graph/"

    if graph_type:lower() == "dot" then
        local dot_result = vim.system(
            { "dot", "-Tpng", "-o", filename .. ".png", filename .. ".dot" },
            { cwd = graph_dir, text = true }
        ):wait()

        if dot_result.code ~= 0 then
            vim.notify(
                string.format(
                    "error generating png:\n%s",
                    dot_result.stderr or ""
                ),
                vim.log.levels.ERROR
            )
            return
        end

        vim.system(
            { "xdg-open", graph_dir .. filename .. ".png" },
            { detach = true }
        )
    elseif graph_type:lower() == "d3" then
        vim.system(
            { "xdg-open", graph_dir .. filename .. ".html" },
            { detach = true }
        )
    end
end

-- Show bob status for the current project (TODO: not yet implemented).
function M.status(...)
    M.check_init()
    vim.notify("TODO: status", vim.log.levels.INFO)
end

-- Search packages by pattern (TODO: not yet implemented).
function M.search(bang, pattern)
    M.check_init()
    vim.notify("TODO: search implementation", vim.log.levels.INFO)
end

-- Merge the given config table into the active configuration (called from setup()).
function M.configure(config)
    cfg = vim.tbl_deep_extend("force", cfg, config)
end

-- Query src and build paths for a list of packages using `bob query-path`.
-- Runs batches of 10 in parallel. On error, removes the offending package and retries.
-- Returns { list = [...], result = [...] } where result lines have
-- format "{name} | {src} | {build}".
function M.query_paths(package_list, query_params)
    -- Do not use vim.g.bob_prefix here: paths must be valid on the host, not
    -- inside a container, because they are consumed by code navigation and LSP
    -- (clangd/YCM) which run on the host.
    local cwd = vim.fn.expand(state.bob_base_path)

    -- Write packages to temp file to avoid CLI length limits.
    -- At some projects it could be a lot of packages
    local tmpfile = vim.fn.tempname()
    vim.fn.writefile(package_list, tmpfile)

    -- Use xargs to use packages from the temp file
    local cmd_str = "xargs -a "
        .. vim.fn.shellescape(tmpfile)
        .. " bob query-path --fail -f '{name} | {src} | {build}' "
        .. table.concat(query_params, " ")
        .. " 2>&1"

    if vim.g.bob_verbose == 1 then
        vim.notify(cmd_str)
    end

    local proc = vim.system(
        { "bash", "-lc", cmd_str },
        { cwd = cwd, text = true }
    )
        :wait()
    vim.fn.delete(tmpfile)

    local output = M.remove_info(proc.stdout or "")
    local result = vim.split(output, "\n", { trimempty = true })

    if vim.g.bob_verbose == 1 then
        vim.notify(table.concat(result, "\n"))
    end

    -- Error handling: a package without a build directory causes bob to fail.
    -- Parse which package caused it, remove it, and retry.
    if proc.code ~= 0 then
        local joined = table.concat(result, " ")
        local err_package = joined:match(
            "Director%w+ for {[^}]+} steps? of package (%S+) not present%."
        )

        if not err_package then
            local msg = "Could not parse Bob error message: " .. joined
            vim.notify(msg, vim.log.levels.ERROR)
            error(msg)
        end

        if vim.g.bob_verbose == 1 then
            vim.notify(
                string.format(
                    "Error calling '%s': %s Removing package and retrying ...",
                    cmd_str,
                    joined
                )
            )
        end

        local new_list = {}
        for _, item in ipairs(package_list) do
            if item:sub(-#err_package) ~= err_package then
                table.insert(new_list, item)
            elseif vim.g.bob_verbose == 1 then
                vim.notify("removing " .. item .. " from package list")
            end
        end

        vim.notify(
            string.format("ignoring package %s", err_package),
            vim.log.levels.WARN
        )

        if #package_list > 1 then
            return M.query_paths(new_list, query_params)
        else
            local msg =
                "None of the packages provides src and build directories."
            vim.notify(msg, vim.log.levels.ERROR)
            error(msg)
        end
    end

    return { list = package_list, result = result }
end

-- Set up project mode for the given package: queries src/build paths for all
-- recursive dependencies, registers autocommands for lcd and readonly, and
-- generates the merged compile_commands.json.
function M.project_impl(package, args)
    local project_name = package
    local project_options = args.args or {}

    if vim.g.bob_verbose then
        vim.notify("generating query options from options")
        vim.print(project_options)
    end

    -- Filter out build-only options that are not valid for bob query-path.
    local project_query_options = {}
    local skip_next = false

    for _, elem in ipairs(project_options) do
        if skip_next then
            -- Previous element was a two-part flag: skip its value.
            skip_next = false
        else
            local is_two_part =
                vim.tbl_contains(cfg.bob_query_option_filter_values, elem)
            local is_filtered = false
            for _, pattern in ipairs(cfg.bob_query_option_filters) do
                if elem:match(pattern) then
                    is_filtered = true
                    break
                end
            end

            if is_two_part then
                -- Two-part option (e.g. --destination <dir>): skip flag and next value.
                skip_next = true
            elseif is_filtered then
                -- Single option not suitable for bob query-path: skip it.
                if vim.g.bob_verbose then
                    vim.notify("removing: " .. elem)
                end
            else
                table.insert(project_query_options, elem)
            end
        end
    end

    local project_config = ""
    if args.config then
        project_config =
            string.format("-c %s/%s", state.bob_config_path, args.config)
    end

    -- Get the full recursive package list for the project.
    local ls_cmd = { "bob", "ls", "--prefixed", "--recursive" }
    if project_config ~= "" then
        vim.list_extend(
            ls_cmd,
            vim.split(project_config, "%s+", { trimempty = true })
        )
    end
    vim.list_extend(ls_cmd, project_query_options)
    table.insert(ls_cmd, package)

    local ls_result =
        vim.system(ls_cmd, { cwd = state.bob_base_path, text = true }):wait()

    if ls_result.code ~= 0 then
        vim.notify(
            string.format("bob ls failed: %s", vim.trim(ls_result.stdout or "")),
            vim.log.levels.ERROR
        )
        return
    end

    local list = M.remove_info(ls_result.stdout or "")

    local package_list = vim.split(vim.trim(list), "\n")
    table.insert(package_list, package)

    vim.notify("gather package paths ...", vim.log.levels.INFO)

    local query_params = vim.list_extend({}, project_query_options)
    table.insert(query_params, project_config)

    local query
    local ok, err = pcall(function()
        query = M.query_paths(package_list, query_params)
    end)

    if not ok then
        vim.notify(
            string.format("Querying paths failed: %s", err),
            vim.log.levels.ERROR
        )
        return
    end

    -- Collect per-package source and build directories from query results.
    local project_package_src_dirs = {}
    local project_package_build_dirs = {}

    for idx, pkg in ipairs(query.list) do
        local line = query.result[idx]
        local matches = vim.fn.matchlist(line, [[^\(.*\) | \(.*\) | \(.*\)$]])

        if vim.tbl_isempty(matches) then
            if vim.g.bob_verbose then
                vim.notify("skipped caching of " .. pkg)
            end
        else
            if vim.g.bob_verbose then
                vim.notify("caching " .. pkg)
            end
            project_package_src_dirs[pkg] = matches[3]
            project_package_build_dirs[pkg] = matches[4]
        end
    end

    -- Build a reduced name map: use the short (leaf) package name when it
    -- maps to exactly one unique source directory; otherwise keep the full
    -- path-qualified name to avoid ambiguity.
    vim.notify("generate short package names ...", vim.log.levels.INFO)

    local map_short_to_long_names = {}
    for long_name in pairs(project_package_src_dirs) do
        local short_name = long_name:gsub("^.*/", "")
        map_short_to_long_names[short_name] = map_short_to_long_names[short_name]
            or {}
        table.insert(map_short_to_long_names[short_name], long_name)
    end

    local project_package_src_dirs_reduced = {}
    for short_name, long_names in pairs(map_short_to_long_names) do
        local all_dirs = vim.tbl_map(function(n)
            return project_package_src_dirs[n]
        end, long_names)
        local unique_dirs = vim.fn.uniq(vim.fn.sort(all_dirs))

        if #unique_dirs == 1 then
            project_package_src_dirs_reduced[short_name] =
                project_package_src_dirs[long_names[1]]
        else
            for _, long_name in ipairs(long_names) do
                project_package_src_dirs_reduced[long_name] =
                    project_package_src_dirs[long_name]
            end
        end
    end

    if vim.g.bob_verbose then
        vim.print(project_package_src_dirs_reduced)
    end

    -- Mark dist/build directories as read-only to prevent accidental edits.
    vim.api.nvim_create_augroup("vim_bob_readonly_dist", { clear = true })
    vim.api.nvim_create_autocmd("BufReadPost", {
        group = "vim_bob_readonly_dist",
        pattern = {
            state.bob_base_path .. "/dev/dist/*",
            state.bob_base_path .. "/dev/build/*",
        },
        callback = function()
            vim.opt_local.readonly = true
        end,
    })

    -- lcd into the relevant source directory when opening files in the project.
    vim.api.nvim_create_augroup("vim_bob_cd_source", { clear = true })
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = "vim_bob_cd_source",
        pattern = state.bob_base_path .. "/*",
        command = "lcd " .. state.bob_base_path,
    })

    for _, src_path in pairs(project_package_src_dirs_reduced) do
        local full = state.bob_base_path .. "/" .. src_path
        vim.api.nvim_create_autocmd("BufWinEnter", {
            group = "vim_bob_cd_source",
            pattern = full .. "/*",
            command = "lcd " .. full,
        })
    end

    -- Persist project state
    state.project_name = project_name
    state.project_options = project_options
    state.project_query_options = project_query_options
    state.project_config = project_config
    state.project_package_build_dirs = project_package_build_dirs
    state.project_package_src_dirs = project_package_src_dirs
    state.project_package_src_dirs_reduced = project_package_src_dirs_reduced

    M.compilation_database()
end

-- Merge per-package compile_commands.json files into dev/compile_commands.json and
-- generate .ycm_extra_conf.py. If bob_prefix is set, rewrites container paths to host paths.
function M.compilation_database()
    M.check_init()

    -- Generate .ycm_extra_conf.py from the template, substituting the build path.
    local script_path = debug.getinfo(1).source:match("@?(.*/)")
    local template_file = script_path .. "/ycm_extra_conf.py.template"

    local template = vim.fn.readfile(template_file)
    for i, line in ipairs(template) do
        template[i] = line:gsub("@db_path@", state.bob_base_path .. "/dev")
    end
    vim.fn.writefile(template, state.bob_base_path .. "/dev/.ycm_extra_conf.py")

    -- Merge all per-package compile_commands.json files into one aggregate
    -- database at dev/compile_commands.json.
    local compile_db = state.bob_base_path .. "/dev/compile_commands.json"
    local merged = { "[" }

    local build_dirs = vim.fn.uniq(
        vim.fn.sort(vim.tbl_values(state.project_package_build_dirs))
    )

    for _, build_dir in ipairs(build_dirs) do
        if vim.g.bob_verbose then
            vim.notify("checking for compile_commands.json in " .. build_dir)
        end

        local file = string.format(
            "%s/%s/compile_commands.json",
            state.bob_base_path,
            build_dir
        )

        if vim.fn.filereadable(file) == 1 then
            if vim.g.bob_verbose then
                vim.notify("found")
            end

            local entries = vim.fn.readfile(file)
            -- Skip the opening '[' (index 1) and closing ']' (last) of each file.
            for i = 2, #entries - 1 do
                table.insert(merged, entries[i])
            end
            table.insert(merged, ",")
        end
    end

    if #merged > 0 then
        merged[#merged] = "]"
    end

    -- If building inside a container, translate container-side paths to their
    -- host equivalents so that LSP tools (clangd, YCM) running on the host
    -- can resolve them.
    if vim.g.bob_prefix ~= nil and vim.g.bob_prefix ~= "" then
        local pwd_result = vim.system(
            { "bash", "-c", vim.g.bob_prefix .. " pwd" },
            { text = true }
        ):wait()

        if pwd_result.code ~= 0 then
            vim.notify(
                string.format(
                    "error getting container workdir: %s",
                    vim.trim(pwd_result.stdout or "")
                ),
                vim.log.levels.ERROR
            )
            return
        end

        local prefix_path = vim.trim(pwd_result.stdout or "")

        -- Match paths that are preceded by a quote, equals sign, space, or
        -- compiler flag character to avoid replacing unrelated substrings.
        local path_preceding_chars = [[\(["'=]\| -i\| -I\|\(\\\)\@<! \)\zs]]

        local pattern = path_preceding_chars .. vim.pesc(prefix_path) .. "/"
        local substitute = state.bob_base_path .. "/"

        local text_subst = {}
        for _, line in ipairs(merged) do
            table.insert(
                text_subst,
                vim.fn.substitute(line, pattern, substitute, "g")
            )
        end

        merged = text_subst
    end

    vim.fn.writefile(merged, compile_db)
end

-- Build a package with `bob dev` without entering project mode (TODO: not yet implemented).
function M.dev(bang, args)
    M.check_init()
    vim.notify("TODO: dev implementation", vim.log.levels.INFO)
end

-- Print the current plugin state to the Neovim message area (for debugging).
function M.inspect()
    M.check_init()

    if state.project_name and state.project_name ~= "" then
        vim.notify(string.format("base_path: %s", state.bob_base_path))

        vim.notify(string.format("project_name: %s", state.project_name))

        vim.notify(
            string.format("project_config: %s", state.project_config or "")
        )

        vim.notify(
            string.format(
                "project_options: %s",
                table.concat(state.project_options or {}, ", ")
            )
        )

        vim.notify(
            string.format(
                "project_query_options: %s",
                table.concat(state.project_query_options or {}, ", ")
            )
        )

        vim.notify("project_package_build_dirs:")

        for key, value in pairs(state.project_package_build_dirs or {}) do
            vim.notify(string.format("    %s: %s", key, value))
        end

        vim.notify("project_package_src_dirs:")

        for key, value in pairs(state.project_package_src_dirs or {}) do
            vim.notify(string.format("    %s: %s", key, value))
        end

        vim.notify("project_package_src_dirs_reduced:")

        for key, value in pairs(state.project_package_src_dirs_reduced or {}) do
            vim.notify(string.format("    %s: %s", key, value))
        end
    end

    vim.notify(
        string.format(
            "bob_reduce_goto_list: %s",
            tostring(vim.g.bob_reduce_goto_list)
        )
    )

    vim.notify(
        string.format(
            "bob_auto_complete_items: %s",
            table.concat(vim.g.bob_auto_complete_items or {}, ", ")
        )
    )

    vim.notify(string.format("bob_verbose: %s", tostring(vim.g.bob_verbose)))

    vim.notify(
        string.format("bob_prefix: %s", tostring(vim.g.bob_prefix or ""))
    )
end

return M
