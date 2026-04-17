cmake_minimum_required(VERSION 3.13)

# Make sure 'set' for variables is respected by options in nested files
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
# Honor CMAKE_INTERPROCEDURAL_OPTIMIZATION in subprojects (e.g. boringssl, luau)
# whose minimum CMake version predates CMP0069 defaulting to NEW.
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
if (LUTE_ENABLE_SANITIZERS)
    if(NOT MSVC)
        add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
        add_link_options(-fsanitize=address,undefined)
    endif()
endif()

# Size-optimization knobs applied globally so external libraries (luau,
# boringssl, curl, libuv, zlib, ...) pick them up too. These are the biggest
# single lever for reducing the final binary size, especially on Linux where
# ld doesn't strip unreferenced functions by default.
option(LUTE_OPTIMIZE_SIZE "Enable binary size optimizations for release builds" ON)
if (LUTE_OPTIMIZE_SIZE AND NOT LUTE_ENABLE_SANITIZERS)
    # Generator expression that is true for any non-Debug config. We want
    # these flags for Release, MinSizeRel and RelWithDebInfo but not Debug.
    set(_lute_release_cfg "$<NOT:$<CONFIG:Debug>>")

    if (NOT MSVC)
        # Emit each function/data symbol into its own section so the linker
        # can drop unreferenced ones.
        add_compile_options(
            "$<${_lute_release_cfg}:-ffunction-sections>"
            "$<${_lute_release_cfg}:-fdata-sections>"
        )

        if (APPLE)
            # ld64 already dead-strips by default; make it explicit.
            add_link_options("$<${_lute_release_cfg}:-Wl,-dead_strip>")
        else()
            # GNU ld / lld / gold
            add_link_options("$<${_lute_release_cfg}:-Wl,--gc-sections>")
        endif()
    else()
        # MSVC equivalents: /Gy = function-level linking, /Gw = package
        # global data, /OPT:REF + /OPT:ICF = drop unused + fold identical.
        # Restrict compile flags to C/C++ so they don't leak into the nasm
        # invocations used by BoringSSL's AVX assembly on Windows (nasm
        # treats `/Gy` as an input filename and errors out).
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

    # Enable LTO/IPO for size-relevant configs if the toolchain supports it.
    # Setting the per-config variable here means every target created in
    # subsequent add_subdirectory() calls inherits it.
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
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static zlib" FORCE)
add_subdirectory(extern/zlib)

set(ZLIB_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/extern/zlib")

set(ZLIB_FOUND TRUE CACHE BOOL "" FORCE)

if(MSVC)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/zlibstaticd.lib")
    else()
        set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/zlibstatic.lib")
    endif()
else()
    set(ZLIB_LIBRARY "${ZLIB_OUTPUT_DIR}/libz.a")
endif()
set(ZLIB_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/zlib;${ZLIB_OUTPUT_DIR})
set(ZLIB_INCLUDE_DIRS ${ZLIB_INCLUDE_DIR} CACHE STRING "" FORCE)

# boringssl setup
add_subdirectory(extern/boringssl)
set(BORINGSSL_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/extern/boringssl")
set(BORINGSSL_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/extern/boringssl/include)

# Suppress frame-size warnings in boringssl when sanitizers are enabled
if (LUTE_ENABLE_SANITIZERS AND NOT MSVC)
    target_compile_options(crypto PRIVATE -Wno-frame-larger-than)
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

# Disable curl protocols that lute/net never uses. The net client in
# `lute/net/src/client.cpp` only speaks HTTP/HTTPS, and the websocket client
# in `lute/net/src/client_websocket.cpp` uses CURLOPT_CONNECT_ONLY=2 (curl's
# WebSocket mode), so HTTP and WebSockets must remain enabled.
#
# We intentionally leave the following enabled since they affect user-visible
# behavior for HTTP: cookies, auth (basic/bearer/digest/kerberos/negotiate/
# NTLM), proxy, netrc, HSTS, alt-svc, DoH, verbose error strings.
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

# executables
add_subdirectory(lute/cli)
add_subdirectory(tests)
