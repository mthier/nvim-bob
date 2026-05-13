local M = {
    bob_config_path = "configurations",
    bob_graph_type = "dot",
    bob_prefix_list = {
        none = "",
        ["vic/opensuse:leap15.3-full"] = "docker run --rm -e HOST_UID=\"$(id -u)\" -e HOST_GID=\"$(id -g)\" -v \"$HOME/.ssh/config_build_container:/etc/skel/.ssh/config\" -v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK -v \"$(pwd):/build\" -v \"$HOME/.config/bob/:/etc/skel/.config/bob/\" -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -e MAGIC=$(xauth nlist $DISPLAY | head -1 | cut -d\" \" -f9) vic/opensuse:leap15.3-full",
        ["roc7-build-develop"] = "docker run --rm -e HOST_UID=\"$(id -u)\" -e HOST_GID=\"$(id -g)\" -v \"$HOME/.ssh/config_build_container:/etc/skel/.ssh/config\" -v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK -v \"$(pwd):/work\" -v \"$HOME/.config/bob/:/etc/skel/.config/bob/\" -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -e MAGIC=$(xauth nlist $DISPLAY | head -1 | cut -d\" \" -f9) roc7-build-develop",
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
