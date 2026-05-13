cmake_minimum_required(VERSION 3.15)

project(lib_b)

find_package(lib_a REQUIRED)

add_library(lib_b STATIC
    src/lib_b.cpp
)

target_include_directories(lib_b
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

target_link_libraries(lib_b PRIVATE lib_a)

install(DIRECTORY include/
    DESTINATION include
)

install(TARGETS lib_b
    EXPORT lib_bTargets
    ARCHIVE DESTINATION lib
)

# Export the cmake-Config-File to use find_package()
install(EXPORT lib_bTargets
    FILE lib_bConfig.cmake
    DESTINATION lib/cmake/lib_b
)
