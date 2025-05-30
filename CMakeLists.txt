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

# Get the proper extension for static libraries
if(MSVC)
  set(LIB_EXT ".lib")
else()
  set(LIB_EXT ".a")
endif()

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

# zlib setup
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static zlib" FORCE)
add_subdirectory(extern/zlib)
set(ZLIB_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/extern/zlib")

set(ZLIB_FOUND TRUE CACHE BOOL "" FORCE)
set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/libz${LIB_EXT}")
set(ZLIB_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/zlib;${ZLIB_OUTPUT_DIR})
set(ZLIB_INCLUDE_DIRS ${ZLIB_INCLUDE_DIR} CACHE STRING "" FORCE)

# boringssl setup
add_subdirectory(extern/boringssl)
set(BORINGSSL_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/extern/boringssl")
set(BORINGSSL_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/boringssl/include)

# we must empower ourselves with the spells necessary to block _all further mutation_ to a variable

function(protect_variable_callback variable access value current_list_file stack)
    message(STATUS "[PROTECT] ${access} on ${variable}")
    if(access STREQUAL "MODIFIED_ACCESS" OR access STREQUAL "REMOVED_ACCESS")
        get_property(original_value GLOBAL PROPERTY _PROTECTED_${variable}_VALUE)

        set(${variable} "${original_value}" CACHE INTERNAL "Protected variable" FORCE)

        message(WARNING "[PROTECT] Attempt to modify protected variable ${variable} was blocked (in ${current_list_file})")
        message(STATUS "[PROTECT] Written value: '${value}'")
        message(STATUS "[PROTECT] Protected value restored: '${original_value}'")
        message(STATUS "[PROTECT] Reading ${variable} now gives ${${variable}}")
    endif()
endfunction()

function(set_protected_variable var_name value)
    set_property(GLOBAL PROPERTY _PROTECTED_${var_name}_VALUE "${value}")
    set(${var_name} "${value}" CACHE INTERNAL "Protected variable" FORCE)
    variable_watch(${var_name} protect_variable_callback)
endfunction()

# Path to the actual files

# find_package is an evil demon, and we must use powerful spells to bind it
set_protected_variable(OPENSSL_SSL_LIBRARY "${BORINGSSL_OUTPUT_DIR}/libssl${LIB_EXT}")
set_protected_variable(OPENSSL_CRYPTO_LIBRARY "${BORINGSSL_OUTPUT_DIR}/libcrypto${LIB_EXT}")
set_protected_variable(OPENSSL_SSL_LIBRARIES "${OPENSSL_SSL_LIBRARY}")
set_protected_variable(OPENSSL_CRYTPO_LIBRARIES "${OPENSSL_CRYTPO_LIBRARY}")
set_protected_variable(OPENSSL_LIBRARIES "${OPENSSL_SSL_LIBRARY};${OPENSSL_CRYPTO_LIBRARY}")

add_library(OpenSSL::SSL STATIC IMPORTED GLOBAL)
set_target_properties(OpenSSL::SSL PROPERTIES
    IMPORTED_LOCATION "${BORINGSSL_OUTPUT_DIR}/libssl${LIB_EXT}"
    INTERFACE_INCLUDE_DIRECTORIES "${BORINGSSL_INCLUDE_DIR}"
)

add_library(OpenSSL::Crypto STATIC IMPORTED GLOBAL)
set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LOCATION "${BORINGSSL_OUTPUT_DIR}/libcrypto${LIB_EXT}"
    INTERFACE_INCLUDE_DIRECTORIES "${BORINGSSL_INCLUDE_DIR}"
)


set_protected_variable(OPENSSL_FOUND TRUE CACHE BOOL "Found BoringSSL")
set_protected_variable(OPENSSL_VERSION "3.0.0" CACHE STRING "Dummy version, BoringSSL")
set_protected_variable(OPENSSL_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/extern/boringssl/")
set_protected_variable(OPENSSL_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/extern/boringssl/include")
set_protected_variable(OPENSSL_INCLUDE_DIRS "${OPENSSL_INCLUDE_DIR}")

# FindOpenSSL with MSVC is the problem...
if(MSVC)
    set_protected_variable(SSL_EAY_LIBRARY "${OPENSSL_SSL_LIBRARY}")
    set_protected_variable(LIB_EAY_LIBRARY "${OPENSSL_CRYTPO_LIBRARY}")
endif()

# curl setup

set(USE_LIBIDN2 OFF)
set(USE_NGHTTP2 OFF)
set(CURL_USE_LIBPSL OFF)
set(CURL_USE_LIBSSH2 OFF)
set(CURL_ZLIB ON)
set(CURL_BROTLI OFF CACHE STRING "Disable brotli support" FORCE)
set(CURL_ENABLE_SSL ON)
set(CURL_USE_OPENSSL ON)
set(BUILD_EXAMPLES OFF)
set(BUILD_CURL_EXE OFF)
set(BUILD_SHARED_LIBS OFF)
set(BUILD_STATIC_LIBS ON)

set(HAVE_BORINGSSL ON)
add_subdirectory(extern/curl)

# uWebSockets setup
set(WITH_BORINGSSL ON)
set(WITH_LIBUV ON)
set(WITH_ZLIB ON)

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

# libraries
add_subdirectory(lute/runtime)
add_subdirectory(lute/crypto)
add_subdirectory(lute/fs)
add_subdirectory(lute/luau)
add_subdirectory(lute/net)
add_subdirectory(lute/std)
add_subdirectory(lute/task)
add_subdirectory(lute/vm)
add_subdirectory(lute/process)
add_subdirectory(lute/system)
add_subdirectory(lute/time)

# executables
add_subdirectory(lute/cli)
add_subdirectory(tests)
