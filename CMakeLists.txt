cmake_minimum_required(VERSION 3.14)

# Make sure 'set' for variables is respected by options in nested files
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

project(
    Lute
    VERSION 0.1
    LANGUAGES CXX C
)

project(Lute LANGUAGES CXX C VERSION ${LUTE_VERSION})

include(tools/embed_map.cmake)
include(tools/embed_file.cmake)
include(tools/CPM.cmake)

include(Dependencies.cmake)

set(LUTE_OPTIONS)

if(MSVC)
    list(APPEND LUTE_OPTIONS /DNOMINMAX)
    list(APPEND LUTE_OPTIONS /D_CRT_SECURE_NO_WARNINGS) # We need to use the portable CRT functions.
    list(APPEND LUTE_OPTIONS "/we4018") # Signed/unsigned mismatch
    list(APPEND LUTE_OPTIONS "/we4388") # Also signed/unsigned mismatch
    list (APPEND LUTE_OPTIONS "/Zc:externConstexpr") # MSVC does not comply with C++ standard by default
    # FIXME: list(APPEND LUTE_OPTIONS /WX) # Warnings are errors
else()
    list(APPEND LUTE_OPTIONS -Wall) # All warnings
    list(APPEND LUTE_OPTIONS -Wimplicit-fallthrough)
    list(APPEND LUTE_OPTIONS -Wsign-compare) # This looks to be included in -Wall for GCC but not clang
    list(APPEND LUTE_OPTIONS -Werror) # Warnings are errors
endif()

add_subdirectory(runtime)
add_subdirectory(crypto)
add_subdirectory(fs)
add_subdirectory(luau)
add_subdirectory(net)
add_subdirectory(std)
add_subdirectory(task)
add_subdirectory(vm)
add_subdirectory(process)
add_subdirectory(system)
add_subdirectory(time)
add_subdirectory(cli)