cmake_minimum_required(VERSION 3.13)

if(APPLE AND NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum macOS version")
endif()

# Make sure 'set' for variables is respected by options in nested files
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
# Let subprojects inherit CMAKE_INTERPROCEDURAL_OPTIMIZATION.
set(CMAKE_POLICY_DEFAULT_CMP0069 NEW)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# set the module path
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMakeBuild")

include(get_version)

project(
    Lute
    VERSION ${LUTE_VERSION}
    LANGUAGES CXX C
)

# Enable sanitizers globally before any subdirectory is added
option(LUTE_ENABLE_SANITIZERS "Enable sanitizers" OFF)
option(LUTE_STDLESS "Build without embedded Luau sources (for bootstrapping)" OFF)
if (LUTE_ENABLE_SANITIZERS)
    if(NOT MSVC)
        add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
        add_link_options(-fsanitize=address,undefined)
    endif()
endif()

option(LUTE_OPTIMIZE_SIZE "Enable binary size optimizations for release builds" ON)
if (LUTE_OPTIMIZE_SIZE AND NOT LUTE_ENABLE_SANITIZERS)
    set(_lute_release_cfg "$<NOT:$<CONFIG:Debug>>")

    if (NOT MSVC)
        add_compile_options(
            "$<${_lute_release_cfg}:-ffunction-sections>"
            "$<${_lute_release_cfg}:-fdata-sections>"
            "$<${_lute_release_cfg}:-fvisibility=hidden>"
            "$<${_lute_release_cfg}:$<$<COMPILE_LANGUAGE:CXX>:-fvisibility-inlines-hidden>>"
        )

        if (APPLE)
            add_link_options("$<${_lute_release_cfg}:-Wl,-dead_strip>")
        else()
            add_link_options("$<${_lute_release_cfg}:-Wl,--gc-sections>")
        endif()
    else()
        # Restrict to C/C++ so /Gy and /Gw don't leak into NASM invocations.
        set(_lute_cxx_lang "$<OR:$<COMPILE_LANGUAGE:C>,$<COMPILE_LANGUAGE:CXX>>")
        add_compile_options(
            "$<${_lute_release_cfg}:$<${_lute_cxx_lang}:/Gy>>"
            "$<${_lute_release_cfg}:$<${_lute_cxx_lang}:/Gw>>"
        )
        add_link_options(
            "$<${_lute_release_cfg}:/OPT:REF>"
            "$<${_lute_release_cfg}:/OPT:ICF>"
        )
    endif()

    include(CheckIPOSupported)
    check_ipo_supported(RESULT LUTE_IPO_SUPPORTED OUTPUT LUTE_IPO_ERROR)
    if (LUTE_IPO_SUPPORTED)
        message(STATUS "Lute: enabling LTO for Release/MinSizeRel/RelWithDebInfo")
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL TRUE)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO TRUE)
    else()
        message(STATUS "Lute: LTO not supported by this toolchain: ${LUTE_IPO_ERROR}")
    endif()
endif()

# LUTE_EXTERN_C must be declared before extern/luau is configured so that
# it can force LUAU_EXTERN_C on — Luau must use longjmp instead of C++
# exceptions when lute's open functions are exposed with C linkage.
option(LUTE_EXTERN_C "Use extern C Lute API functions" OFF)
if(LUTE_EXTERN_C)
    set(LUAU_EXTERN_C ON)
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
#
set(ZLIB_BUILD_EXAMPLES OFF CACHE BOOL "Do not build examples" FORCE)
set(ZLIB_BUILD_TESTING OFF CACHE BOOL "Do not build zlib tests" FORCE)
set(ZLIB_BUILD_SHARED OFF CACHE BOOL "Do not build shared zlib" FORCE)
set(ZLIB_BUILD_STATIC ON CACHE BOOL "Build static zlib" FORCE)
set(ZLIB_INSTALL OFF CACHE BOOL "Do not install zlib" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static zlib" FORCE)
add_subdirectory(extern/zlib)
if(TARGET zlibstatic AND NOT TARGET ZLIB::ZLIB)
    add_library(ZLIB::ZLIB INTERFACE IMPORTED GLOBAL)
    target_link_libraries(ZLIB::ZLIB INTERFACE "$<BUILD_INTERFACE:zlibstatic>")
endif()

set(ZLIB_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/extern/zlib")

if(MSVC)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/zlibstaticd.lib" CACHE FILEPATH "" FORCE)
    else()
        set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/zlibstatic.lib" CACHE FILEPATH "" FORCE)
    endif()
else()
    set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/libz.a" CACHE FILEPATH "" FORCE)
endif()
set(ZLIB_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/zlib;${ZLIB_OUTPUT_DIR} CACHE PATH "" FORCE)
set(ZLIB_INCLUDE_DIRS ${ZLIB_INCLUDE_DIR} CACHE STRING "" FORCE)
set(ZLIB_LIBRARIES ZLIB::ZLIB CACHE STRING "" FORCE)

# boringssl setup
set(BUILD_TESTING OFF)
add_subdirectory(extern/boringssl)
set(BORINGSSL_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/extern/boringssl")
set(BORINGSSL_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/boringssl/include)

# Suppress frame-size warnings in boringssl when sanitizers are enabled
if (LUTE_ENABLE_SANITIZERS AND NOT MSVC)
    target_compile_options(crypto PRIVATE -Wno-frame-larger-than)
endif()

# BoringSSL's _HAS_EXCEPTIONS=0 changes MSVC STL vtables; under /LTCG this
# trips C4743, which BoringSSL's /WX escalates to LNK1257. Keep it out of LTCG.
if (MSVC AND LUTE_OPTIMIZE_SIZE AND NOT LUTE_ENABLE_SANITIZERS AND LUTE_IPO_SUPPORTED)
    foreach(_bssl_target crypto ssl fipsmodule decrepit pki)
        if (TARGET ${_bssl_target})
            set_property(TARGET ${_bssl_target} PROPERTY INTERPROCEDURAL_OPTIMIZATION FALSE)
            set_property(TARGET ${_bssl_target} PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE FALSE)
            set_property(TARGET ${_bssl_target} PROPERTY INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL FALSE)
            set_property(TARGET ${_bssl_target} PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO FALSE)
        endif()
    endforeach()
endif()

# curl setup

set(USE_LIBIDN2 OFF)
set(USE_NGHTTP2 OFF)
set(CURL_USE_LIBPSL OFF)
set(CURL_USE_LIBSSH2 OFF)
set(CURL_ZLIB ON)
SET(CURL_ZSTD OFF CACHE STRING "Disable ZSTD" FORCE)
set(CURL_BROTLI OFF CACHE STRING "Disable brotli support" FORCE)
set(CURL_ENABLE_SSL ON)
set(CURL_USE_OPENSSL ON)
set(BUILD_EXAMPLES OFF)
set(BUILD_CURL_EXE OFF)
set(BUILD_SHARED_LIBS OFF)
set(BUILD_STATIC_LIBS ON)
set(CURL_ENABLE_EXPORT_TARGET OFF)

# curl's OpenSSL-family probes run in nested try-compile projects, where the
# in-tree ZLIB::ZLIB target is not visible. These are false for BoringSSL.
set(HAVE_DES_ECB_ENCRYPT "" CACHE INTERNAL "curl BoringSSL feature probe")
set(HAVE_SSL_SET0_WBIO "" CACHE INTERNAL "curl BoringSSL feature probe")
set(HAVE_OPENSSL_SRP "" CACHE INTERNAL "curl BoringSSL feature probe")

# lute/net only speaks HTTP/HTTPS/WebSocket.
set(CURL_DISABLE_FTP    ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_TFTP   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_FILE   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_DICT   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_TELNET ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAP   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAPS  ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SMB    ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SMTP   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_IMAP   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_POP3   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_GOPHER ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_RTSP   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_MQTT   ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_IPFS   ON CACHE BOOL "" FORCE)

# One more set of DISABLES. We might need to re-enable these at some point
# if we need the features they provide
set(CURL_DISABLE_AWS            ON  CACHE BOOL "" FORCE)
set(CURL_DISABLE_INSTALL        ON  CACHE BOOL "" FORCE)
set(ENABLE_UNIX_SOCKETS         OFF CACHE BOOL "" FORCE)

set(HAVE_BORINGSSL ON)
add_subdirectory(extern/curl)

# uWebSockets setup
set(WITH_BORINGSSL ON)
set(WITH_LIBUV ON)
set(WITH_ZLIB ON)

# Set the correct libuv library name for uWebSockets
set(LIBUV_LIBRARY uv_a)
include(uSockets)
include(uWebSockets)

# Define include directories for uWebSockets and uSockets
set(UWEBSOCKETS_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/uWebSockets/src)

# libsodium for `pwhash`
include(libsodium)

# Lute
set(LUTE_OPTIONS)

if(MSVC)
    list(APPEND LUTE_OPTIONS /DNOMINMAX)
    list(APPEND LUTE_OPTIONS /D_CRT_SECURE_NO_WARNINGS) # We need to use the portable CRT functions.
    list(APPEND LUTE_OPTIONS "/we4018") # Signed/unsigned mismatch
    list(APPEND LUTE_OPTIONS "/we4388") # Also signed/unsigned mismatch
    if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        list(APPEND LUTE_OPTIONS "/Zc:externConstexpr") # MSVC does not comply with C++ standard by default
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        list(APPEND LUTE_OPTIONS "/EHsc") # The CMake clang-cl target doesn't enable exceptions by default
    endif()
    # FIXME: list(APPEND LUTE_OPTIONS /WX) # Warnings are errors
else()
    list(APPEND LUTE_OPTIONS -Wall) # All warnings
    list(APPEND LUTE_OPTIONS -Wimplicit-fallthrough)
    list(APPEND LUTE_OPTIONS -Wsign-compare) # This looks to be included in -Wall for GCC but not clang
    list(APPEND LUTE_OPTIONS -Werror) # Warnings are errors
endif()

# libraries
add_subdirectory(lute/batteries)
add_subdirectory(lute/common)
add_subdirectory(lute/definitions)
add_subdirectory(lute/require)
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
add_subdirectory(lute/io)
add_subdirectory(lute/syntax)

# executables
add_subdirectory(lute/cli)
add_subdirectory(tests)
