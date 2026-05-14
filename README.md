# nvim-bob 

[![CI](https://github.com/mthier/nvim-bob/actions/workflows/ci.yml/badge.svg)](https://github.com/mthier/nvim-bob/actions/workflows/ci.yml)

Neovim plugin for working in a [Bob Build Tool](https://github.com/BobBuildTool/bob) environment.
Lua reimplementation of [vim-bob](https://github.com/ThomasFeher/vim-bob).

## Features

- **Build packages** via `:make` with full quickfix integration
- **Tab completion** for package names, config names, and common build flags
- **Project mode** — maps all recursive package dependencies, sets up `lcd` autocommands so the working directory always follows the open file
- **Dependency graph** — renders a Bob dependency graph and opens it automatically (`dot` or `d3`)
- **LSP / clangd support** — merges per-package `compile_commands.json` files into a single aggregate database and generates a `.ycm_extra_conf.py`
- **Container support** — prefix all Bob invocations with an arbitrary command (e.g. `docker exec …`) via `vim.g.bob_prefix`

## Requirements

- Neovim ≥ 0.12.0
- [Bob Build Tool](https://github.com/BobBuildTool/bob) available in `$PATH`
- `dot` (Graphviz) — only needed for `BobGraph` with `bob_graph_type = "dot"`

## Installation

**[lazy.nvim](https://github.com/folke/lazy.nvim)**

```lua
{
    "mthier/nvim-bob",
    opts = {
        bob_config_path = "configurations",
    },
}
```

**Local (Development)**

```lua
{
    "nvim-bob",
    dev = true,
    dir = "~/Workspace/nvim-bob",
    name = "nvim-bob",
    config = function()
        require("nvim-bob").setup({
            bob_config_path = "configurations",
            bob_graph_type = "dot",
            bob_auto_complete_items = {'-DBUILD_TYPE=Release',
                                       '-DBUILD_TYPE=Debug',
                                       '-DBUILD_SCRIPT_AS_SYMLINK=TRUE',
                                       '--destination dist_folder'}
        })
    end,
}
```

**[packer.nvim](https://github.com/wbthomason/packer.nvim)**

```lua
use {
    "mthier/nvim-bob",
    config = function()
        require("nvim-bob").setup({
            bob_config_path = "configurations",
        })
    end,
}
```

## Configuration

Call `setup()` with any options you want to override. All keys are optional.

```lua
require("nvim-bob").setup({
    -- Relative path (from the Bob workspace root) to the directory containing
    -- YAML build configuration files. Config names are offered as tab
    -- completions for :BobProject and :BobDev.
    bob_config_path = "configurations",

    -- Graph output format passed to `bob graph -t`. Either "dot" (rendered
    -- to PNG via Graphviz and opened with xdg-open) or "d3" (HTML, opened
    -- directly with xdg-open).
    bob_graph_type = "dot",

    -- Extra items appended to tab completion for :BobProject / :BobDev.
    bob_auto_complete_items = {
        "-DBUILD_TYPE=Release",
        "-DBUILD_TYPE=Debug",
        "-DBUILD_SCRIPT_AS_SYMLINK=TRUE",
        "--destination dist_folder",
    },

    -- Named prefix commands selectable via tab completion in :BobInit.
    -- Keys are display names, values are the full shell prefix string.
    bob_prefix_list = {
        none = "",
        ["my-container"] = "docker run --rm -v $(pwd):/build my-container",
    },

    -- Lua patterns for bob dev options that must be stripped before
    -- passing arguments to `bob query-path`.
    bob_query_option_filters = {
        "^%-b$",
        "^%-%-build%-only$",
        "^%-%-clean$",
        "^%-%-force$",
        "^%-%-upload$",
        "^%-%-destination$",
        "^%-%-download$",
    },

    -- Two-part options stripped before `bob query-path` (these consume
    -- the next argument as their value).
    bob_query_option_filter_values = { "--destination", "--download" },
})
```

## Commands

| Command | Description |
|---|---|
| `:BobInit [prefix] [path]` | Initialize the plugin for the Bob workspace at `path` (defaults to `cwd`). Optionally sets a `prefix` command (e.g. `docker run …`) for all Bob invocations. Discovers all available packages and configuration names. Must be run before any other command. |
| `:BobClean` | Delete the `dev/build` and `dev/dist` directories. |
| `:BobDev[!] <pkg> [args…]` | *(not yet implemented)* |
| `:BobProject[!] <pkg> [config] [args…]` | Build `pkg` with `bob dev`, then set up project mode: discovers all recursive package dependencies, maps source/build directories, creates per-directory `lcd` autocommands, and regenerates `dev/compile_commands.json`. |
| `:BobGoto[!] [pkg]` | Change directory into the source directory of `pkg`. With no argument, goes to the workspace root. `!` uses global `cd`; without `!` uses `lcd` (window-local). |
| `:BobGraph` | Generate and open the dependency graph for the current project. Requires a prior `:BobProject` run. |
| `:BobStatus` | *(not yet implemented)* |
| `:BobSearch[!] [pattern]` | *(not yet implemented)* |

### Tab completion

- `:BobInit` completes **prefix strings** from `bob_prefix_list` as the first argument.
- `:BobProject` and `:BobDev` complete **package names** as the first argument, **config names** as the second argument, and `bob_auto_complete_items` for all further arguments.
- `:BobGoto` completes package names. After a `:BobProject` run, completion is restricted to the packages that are part of the project (using short leaf names where unambiguous).

## Global variables

| Variable | Default | Description |
|---|---|---|
| `vim.g.bob_prefix` | `""` | Shell prefix prepended to every Bob invocation (e.g. `"docker exec -it mycontainer"`). When set, container-side paths in `compile_commands.json` are automatically translated to their host equivalents. |
| `vim.g.bob_verbose` | `0` | Set to `1` to enable verbose logging of internal Bob queries. |

## Typical workflow

```
# 1. Open Neovim inside (or point to) a Bob workspace
:BobInit

# 2. Build a package and enter project mode
#    (sets up source navigation and regenerates compile_commands.json)
:BobProject myapp native -DBUILD_TYPE=Debug

# 3. Navigate to a dependency's source
:BobGoto mylib

# 4. Rebuild at any time via the standard :make interface
:make
# or re-run the full project build
:BobProject! myapp native -DBUILD_TYPE=Debug

# 5. Visualise the dependency graph
:BobGraph
```

## Internal flow

### `:BobInit [prefix] [path]`

```mermaid
flowchart TD
    A[":BobInit prefix? path?"] --> B["state.reset()"]
    B --> C{prefix given?}
    C -->|yes| D["resolve from bob_prefix_list\nset vim.g.bob_prefix"]
    C -->|no| E["resolve base path\n(cwd or given path)"]
    D --> E
    E --> F["bob ls  ← sanity check\n(without prefix)"]
    F -->|code ≠ 0| G["notify error, abort"]
    F -->|ok| H{bob_prefix set?}
    H -->|no| I["bob ls"]
    H -->|yes| J["bash -c 'prefix bob ls'"]
    I --> K["remove_info()\nparse package list"]
    J --> K
    K --> L["scan config dir\nfor *.yaml → config_names"]
    L --> M["state populated:\nbob_package_list\nbob_base_path\nconfig_names\nis_initialized = true"]
    M --> N["notify: BobInit successful!"]
```

### `:BobProject[!] pkg [config] [args…]`

```mermaid
flowchart TD
    A[":BobProject! pkg config args"] --> B["check_init()"]
    B --> C["parse args\nconfig = args[1], extra = args[2+]"]
    C --> D["build_cmd()\nassemble shell cmd:\ncd base; prefix bob dev pkg -c config/name args"]
    D --> E["run_make()\npatch shellpipe\nset makeprg\nvim.cmd.make"]
    E -->|build failed| F["notify warning\n(project mode limited)"]
    E -->|build ok| G["project_impl()"]
    F --> G
    G --> H["filter extra args through\nbob_query_option_filters\nbob_query_option_filter_values\n→ project_query_options"]
    H --> I["bob ls --prefixed --recursive\n[config] [query_options] pkg\n→ full dependency list"]
    I --> J["query_paths()\nwrite pkgs to tmpfile\nbash -c 'xargs bob query-path\n--fail -f {name}|{src}|{build}'"]
    J -->|error| K["parse failing pkg\nremove from list\nrecursive retry"]
    K --> J
    J -->|ok| L["parse lines\n→ project_package_src_dirs\n→ project_package_build_dirs"]
    L --> M["build reduced name map\nshort leaf name if unique src dir\notherwise keep full qualified name"]
    M --> N["autocmd vim_bob_readonly_dist\nBufReadPost dev/dist/* dev/build/*\n→ set readonly"]
    N --> O["autocmd vim_bob_cd_source\nBufWinEnter per src_dir/*\n→ lcd into that dir"]
    O --> P["persist project state\n(name, config, dirs, options)"]
    P --> Q["compilation_database()"]
    Q --> R["fill .ycm_extra_conf.py\nfrom template"]
    R --> S["merge compile_commands.json\nfrom all build dirs\n→ dev/compile_commands.json"]
    S --> T{bob_prefix set?}
    T -->|yes| U["bash -c 'prefix pwd'\nrewrite container paths\nto host paths in merged db"]
    T -->|no| V["write dev/compile_commands.json"]
    U --> V
```

### `:BobGoto[!] [pkg]`

> `!` uses global `cd`; without `!` uses window-local `lcd`.

```mermaid
flowchart TD
    A[":BobGoto! pkg?"] --> B["check_init()"]
    B --> C{arg count}
    C -->|0 args| D["cd/lcd state.bob_base_path"]
    C -->|1 arg| E{project loaded?\nproject_package_src_dirs_reduced?}
    E -->|yes| F["lookup pkg in\ncached src dirs"]
    F -->|found| H["lcd/cd base/src_dir"]
    F -->|not found| I["notify: no source dir"]
    E -->|no| G["bob query-path -f '{src}' pkg\n(no prefix — host paths needed)"]
    G -->|code ≠ 0| J["notify error"]
    G -->|ok| K["remove_info()\nextract src path"]
    K -->|empty| L["notify: no sources / not checked out"]
    K -->|ok| H
    C -->|>1 args| M["notify: too many params"]
```

## Container builds

Set `vim.g.bob_prefix` to any wrapper command. The plugin uses the prefix for
`bob dev` invocations (build), but **not** for `bob query-path` (path
resolution), so that source and build paths are always valid on the host where
Neovim and language servers run.

```lua
-- Example: build inside a Docker container
vim.g.bob_prefix = "docker exec -it my-build-container"
```

After a `:BobProject` run, container-side paths in `compile_commands.json` are
replaced with the corresponding host paths so that clangd and YouCompleteMe
work without further configuration.
