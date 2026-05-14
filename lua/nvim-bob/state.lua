local M = {
    is_initialized = false,

    bob_base_path = nil,
    bob_package_list = nil,
    bob_package_tree_list = nil,
    bob_config_path = "",
    bob_config_path_abs = "",
    config_names = {},

    project_name = "",
    project_config = "",
    project_options = {},
    project_query_options = {},

    project_package_src_dirs = {},
    project_package_src_dirs_reduced = {},
    project_package_build_dirs = {},
}

-- Reset all state to initial values. Called when re-initializing with :BobInit.
function M.reset()
    M.is_initialized = false

    M.bob_base_path = nil
    M.bob_package_list = nil
    M.bob_package_tree_list = nil
    M.bob_config_path = ""
    M.bob_config_path_abs = ""
    M.config_names = {}

    M.project_name = ""
    M.project_config = ""
    M.project_options = {}
    M.project_query_options = {}

    M.project_package_src_dirs = {}
    M.project_package_src_dirs_reduced = {}
    M.project_package_build_dirs = {}
end

return M
