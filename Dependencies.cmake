# luau

CPMAddPackage(
    NAME Luau
    GIT_TAG 0.671
    GITHUB_REPOSITORY luau-lang/luau
    OPTIONS "LUAU_BUILD_CLI OFF"
            "LUAU_BUILD_TESTS OFF"
)

# libuv

CPMAddPackage(
    NAME libuv
    VERSION 1.50.0
    GITHUB_REPOSITORY libuv/libuv
    OPTIONS "LIBUV_BUILD_SHARED OFF"
            "BUILD_SHARED_LIBS OFF"
            "LIBUV_BUILD_TESTS OFF"
            "LIBUV_BUILD_BENCH OFF"
)

# boringssl

CPMAddPackage(
    NAME boringssl
    VERSION 0.20250114.0
    GIT_SHALLOW ON
    GITHUB_REPOSITORY google/boringssl
    GIT_TAG 0.20250114.0
    OPTIONS "BUILD_SHARED_LIBS OFF" "BUILD_TESTING OFF"
)

set(OPENSSL_FOUND TRUE CACHE INTERNAL "Force found status for OpenSSL")
set(OPENSSL_INCLUDE_DIR "${boringssl_SOURCE_DIR}/include" CACHE INTERNAL "Include dir for BoringSSL")

add_library(OpenSSL::SSL INTERFACE IMPORTED GLOBAL)
target_link_libraries(OpenSSL::SSL INTERFACE ssl)
target_include_directories(OpenSSL::SSL INTERFACE "${boringssl_SOURCE_DIR}/include")

add_library(OpenSSL::Crypto INTERFACE IMPORTED GLOBAL)
target_link_libraries(OpenSSL::Crypto INTERFACE crypto)
target_include_directories(OpenSSL::Crypto INTERFACE "${boringssl_SOURCE_DIR}/include")

# curl

set(HAVE_BORINGSSL ON)

CPMAddPackage(
  NAME curl
  GITHUB_REPOSITORY curl/curl
  GIT_TAG curl-8_13_0
  OPTIONS
    "USE_LIBIDN2 OFF"
    "USE_NGHTTP2 OFF"
    "CURL_USE_LIBPSL OFF"
    "CURL_USE_LIBSSH2 OFF"
    "CURL_DISABLE_SRP ON"
    "CURL_ZLIB OFF"
    "CURL_BROTLI OFF"
    "BUILD_EXAMPLES OFF"
    "BUILD_CURL_EXE OFF"
    "BUILD_SHARED_LIBS OFF"
    "BUILD_STATIC_LIBS ON"
)

# usockets

set(WITH_BORINGSSL ON)
set(WITH_LIBUV ON)
if(MSVC)
    set(WITH_ZLIB OFF)
endif()
set(LIBUV_LIBRARY uv_a)

include(tools/uSockets.cmake)

# uwebsockets (needs usockets)

include(tools/uWebSockets.cmake)
