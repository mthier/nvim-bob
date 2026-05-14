cmake_minimum_required(VERSION 3.15)
project(app)

# Bob legt das installierte lib-Ergebnis als $2 im buildScript ab.
# Diesen Pfad übergeben wir CMake als CMAKE_PREFIX_PATH.
find_package(lib_a REQUIRED)
find_package(lib_b REQUIRED)

add_executable(app
    main.cpp
)

target_link_libraries(app PRIVATE lib_a lib_b)

install(TARGETS app
    RUNTIME DESTINATION app
)
