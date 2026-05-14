cmake_minimum_required(VERSION 3.15)

project(lib_a)

add_library(lib_a STATIC
    src/lib_a.cpp
)

target_include_directories(lib_a
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

install(DIRECTORY include/
    DESTINATION include
)

install(TARGETS lib_a
    EXPORT lib_aTargets
    ARCHIVE DESTINATION lib
)

# Export the cmake-Config-File to use find_package() 
install(EXPORT lib_aTargets
    FILE lib_aConfig.cmake
    DESTINATION lib/cmake/lib_a
)
