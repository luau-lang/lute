cmake_minimum_required(VERSION 3.13)

# Make sure 'set' for variables is respected by options in nested files
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(get_version.cmake)

project(Lute LANGUAGES CXX C VERSION ${LUTE_VERSION})

add_library(Lute.Runtime STATIC)
add_library(Lute.Crypto STATIC)
add_library(Lute.Fs STATIC)
add_library(Lute.Luau STATIC)
add_library(Lute.Net STATIC)
add_library(Lute.Std STATIC)
add_library(Lute.Task STATIC)
add_library(Lute.VM STATIC)
add_library(Lute.Process STATIC)
add_library(Lute.System STATIC)

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

# boringssl setup
add_subdirectory(extern/boringssl)
set(BORINGSSL_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/boringssl/include)

# boringssl is openssl
set(OPENSSL_FOUND TRUE CACHE INTERNAL "Force found status for OpenSSL")
set(OPENSSL_INCLUDE_DIR ${BORINGSSL_INCLUDE_DIR} CACHE INTERNAL "Include dir for BoringSSL")

add_library(OpenSSL::SSL INTERFACE IMPORTED GLOBAL)
target_link_libraries(OpenSSL::SSL INTERFACE ssl)
target_include_directories(OpenSSL::SSL INTERFACE ${BORINGSSL_INCLUDE_DIR})

add_library(OpenSSL::Crypto INTERFACE IMPORTED GLOBAL)
target_link_libraries(OpenSSL::Crypto INTERFACE crypto)
target_include_directories(OpenSSL::Crypto INTERFACE ${BORINGSSL_INCLUDE_DIR})

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

set(HAVE_BORINGSSL ON)
add_subdirectory(extern/curl)

# uWebSockets setup
set(WITH_BORINGSSL ON)
set(WITH_LIBUV ON)
if(MSVC)
    set(WITH_ZLIB OFF)
endif()

# Set the correct libuv library name for uWebSockets
set(LIBUV_LIBRARY uv_a)
include(extern/uSockets.cmake)
include(extern/uWebSockets.cmake)

# Define include directories for uWebSockets and uSockets
set(UWEBSOCKETS_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/uWebSockets/src)

# Lute Targets

add_executable(Lute.CLI)
set_target_properties(Lute.CLI PROPERTIES OUTPUT_NAME lute)

include(Sources.cmake)

target_compile_features(Lute.Runtime PUBLIC cxx_std_17)
target_compile_features(Lute.Crypto PUBLIC cxx_std_17)
target_compile_features(Lute.Fs PUBLIC cxx_std_17)
target_compile_features(Lute.Luau PUBLIC cxx_std_17)
target_compile_features(Lute.Net PUBLIC cxx_std_17)
target_compile_features(Lute.Std PUBLIC cxx_std_17)
target_compile_features(Lute.Task PUBLIC cxx_std_17)
target_compile_features(Lute.VM PUBLIC cxx_std_17)
target_compile_features(Lute.Process PUBLIC cxx_std_17)
target_compile_features(Lute.System PUBLIC cxx_std_17)
target_include_directories(Lute.Runtime PUBLIC runtime/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Crypto PUBLIC crypto/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Fs PUBLIC fs/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Luau PUBLIC luau/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Net PUBLIC net/include ${LIBUV_INCLUDE_DIR} ${UWEBSOCKETS_INCLUDE_DIR})
target_include_directories(Lute.Std PUBLIC std/include)
target_include_directories(Lute.Task PUBLIC task/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.VM PUBLIC vm/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.Process PUBLIC process/include ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.System PUBLIC system/include ${LIBUV_INCLUDE_DIR})

target_link_libraries(Lute.Runtime PUBLIC Luau.Require PRIVATE Luau.CLI.lib Luau.Compiler Luau.Config Luau.CodeGen Luau.VM Lute.Std uv_a)
target_link_libraries(Lute.Crypto PRIVATE Lute.Runtime Luau.VM uv_a ssl crypto)
target_link_libraries(Lute.Fs PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.Luau PRIVATE Lute.Runtime Luau.VM uv_a Luau.Analysis Luau.Ast Luau.Compiler)
target_link_libraries(Lute.Net PRIVATE Lute.Runtime Luau.VM uv_a libcurl uWS)
target_link_libraries(Lute.Task PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.VM PRIVATE Lute.Runtime Luau.VM Luau.Require uv_a)
target_link_libraries(Lute.Process PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.System PRIVATE Lute.Runtime Luau.VM uv_a)
target_link_libraries(Lute.CLI PRIVATE Luau.CLI.lib Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.Runtime Lute.Crypto Lute.Fs Lute.Luau Lute.Net Lute.Task Lute.VM Lute.Process Lute.System)

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

target_compile_options(Lute.Runtime PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Crypto PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Fs PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Luau PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Net PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Std PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Task PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.VM PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.Process PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.System PRIVATE ${LUTE_OPTIONS})
target_compile_options(Lute.CLI PRIVATE ${LUTE_OPTIONS})
