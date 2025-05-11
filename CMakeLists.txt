cmake_minimum_required(VERSION 3.13)

# Make sure 'set' for variables is respected by options in nested files
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(CMakeBuild/get_version.cmake)

project(
    Lute
    VERSION ${LUTE_VERSION}
    LANGUAGES CXX C
)

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
include(CMakeBuild/uSockets.cmake)
include(CMakeBuild/uWebSockets.cmake)

# Define include directories for uWebSockets and uSockets
set(UWEBSOCKETS_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/uWebSockets/src)

# Lute

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
add_subdirectory(tests)
add_subdirectory(cli)
