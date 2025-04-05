cmake_minimum_required(VERSION 3.13)

# Make sure 'set' for variables is respected by options in nested files
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(get_version.cmake)

project(Lute LANGUAGES CXX C VERSION ${LUTE_VERSION})

add_library(Lute.Runtime STATIC)
add_library(Lute.Fs STATIC)
add_library(Lute.Luau STATIC)
add_library(Lute.Net STATIC)
add_library(Lute.Task STATIC)
add_library(Lute.VM STATIC)
add_library(Lute.Process STATIC)

# luau setup
set(LUAU_BUILD_CLI OFF)
set(LUAU_BUILD_TESTS OFF)

add_subdirectory(extern/luau)

# libuv setup
set(LIBUV_BUILD_SHARED OFF)
set(BUILD_SHARED_LIBS OFF) # why does an option for LIBUV_BUILD_SHARED exist separately
set(LIBUV_BUILD_TESTS OFF)
set(LIBUV_BUILD_BENCH OFF)
add_subdirectory(extern/libuv)

# Define libuv include directory here, before it's needed by other subdirectories
set(LIBUV_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/libuv/include)

# wolfssl setup
set(BUILD_SHARED_LIBS OFF)
set(WOLFSSL_CURL "yes")
set(WOLFSSL_EXAMPLES "no")
set(WOLFSSL_CRYPT_TESTS "no")
set(WOLFSSL_OPENSSLALL "yes")
SET(WOLFSSL_EX_DATA "yes")
add_subdirectory(extern/wolfssl)

# curl setup
set(USE_LIBIDN2 OFF)
set(USE_NGHTTP2 OFF)
set(CURL_USE_LIBPSL OFF)
set(CURL_USE_LIBSSH2 OFF)
set(CURL_ZLIB OFF CACHE STRING "Disable zlib support" FORCE)
set(CURL_BROTLI OFF CACHE STRING "Disable brotli support" FORCE)
set(BUILD_EXAMPLES OFF)
set(BUILD_CURL_EXE OFF)
set(BUILD_SHARED_LIBS OFF)
set(BUILD_STATIC_LIBS ON)

set(CURL_USE_WOLFSSL ON)
set(WOLFSSL_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/wolfssl/include)
set(WOLFSSL_LIBRARY wolfssl)

add_subdirectory(extern/curl)

# uWebSockets setup
set(WITH_WOLFSSL ON)
set(WITH_LIBUV ON)
# Set the correct libuv library name for uWebSockets
set(LIBUV_LIBRARY uv_a)
include(extern/uSockets.cmake)
include(extern/uWebSockets.cmake)

# Define include directories for uWebSockets and uSockets
set(UWEBSOCKETS_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/uWebSockets/src)

#

add_executable(Lute.CLI)
set_target_properties(Lute.CLI PROPERTIES OUTPUT_NAME lute)

include(Sources.cmake)

target_compile_features(Lute.Runtime PUBLIC cxx_std_17)
target_compile_features(Lute.Fs PUBLIC cxx_std_17)
target_compile_features(Lute.Luau PUBLIC cxx_std_17)
target_compile_features(Lute.Net PUBLIC cxx_std_17)
target_compile_features(Lute.Task PUBLIC cxx_std_17)
target_compile_features(Lute.VM PUBLIC cxx_std_17)
target_compile_features(Lute.Process PUBLIC cxx_std_17)
target_include_directories(Lute.Runtime PUBLIC runtime/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Fs PUBLIC fs/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Luau PUBLIC luau/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Net PUBLIC net/include ${LIBUV_INCLUDE_DIR} ${UWEBSOCKETS_INCLUDE_DIR})
target_include_directories(Lute.Task PUBLIC task/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.VM PUBLIC vm/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Process PUBLIC process/include ${LIBUV_INCLUDE_DIR})

target_link_libraries(Lute.Runtime PRIVATE Luau.CLI.lib Luau.Compiler Luau.Config Luau.CodeGen Luau.VM uv_a)
target_link_libraries(Lute.Fs PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.Luau PRIVATE Lute.Runtime Luau.VM uv_a Luau.Analysis Luau.Ast Luau.Compiler)
target_link_libraries(Lute.Net PRIVATE Lute.Runtime Luau.VM uv_a ${WOLFSSL_LIBRARY} libcurl uWS)
target_link_libraries(Lute.Task PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.VM PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.Process PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.CLI PRIVATE Luau.CLI.lib Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.Runtime Lute.Fs Lute.Luau Lute.Net Lute.Task Lute.VM Lute.Process)

set(LUTE_OPTIONS)

if(MSVC)
    list(APPEND LUTE_OPTIONS /DNOMINMAX)
    list(APPEND LUTE_OPTIONS /D_CRT_SECURE_NO_WARNINGS) # We need to use the portable CRT functions.
    list(APPEND LUTE_OPTIONS "/we4018") # Signed/unsigned mismatch
    list(APPEND LUTE_OPTIONS "/we4388") # Also signed/unsigned mismatch
    # FIXME: list(APPEND LUTE_OPTIONS /WX) # Warnings are errors
else()
    list(APPEND LUTE_OPTIONS -Wall) # All warnings
    list(APPEND LUTE_OPTIONS -Wimplicit-fallthrough)
    list(APPEND LUTE_OPTIONS -Wsign-compare) # This looks to be included in -Wall for GCC but not clang
    list(APPEND LUTE_OPTIONS -Werror) # Warnings are errors
endif()

target_compile_options(Lute.Runtime PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Fs PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Luau PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Net PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Task PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.VM PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Process PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.CLI PRIVATE ${LUTE_OPTIONS})
