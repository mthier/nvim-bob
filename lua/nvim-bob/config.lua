local M = {
    bob_config_path = "configurations",
    bob_graph_type = "dot",
    bob_prefix_list = {
        none = "",
        ["bob-test"] = "docker run --rm -v \"$(pwd):/build\" -v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK -v \"$HOME/.config/bob/:/etc/skel/.config/bob/\" -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -e MAGIC=$(xauth nlist $DISPLAY | head -1 | cut -d\" \" -f9) bob-test",
    },
    bob_auto_complete_items = {
        "-DBUILD_TYPE=Release",
        "-DBUILD_TYPE=Debug",
        "-DBUILD_SCRIPT_AS_SYMLINK=TRUE",
        "--destination dist_folder",
    },
    -- Lua patterns for options not suitable for bob query-path.
    bob_query_option_filters = {
        "^%-b$",
        "^%-%-build%-only$",
        "^%-v+$",
        "^%-%-verbose$",
        "^%-%-clean$",
        "^%-%-force$",
        "^%-q+$",
        "^%-j%d*$",
        "^%-%-jobs%d*$",
        "^%-%-upload$",
        "^%-%-destination$",
        "^%-%-download$",
    },
    -- Options not suitable for bob query-path that consume the next argument as their value.
    bob_query_option_filter_values = { "--destination", "--download" },
}

return M
