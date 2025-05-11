cmake_minimum_required(VERSION 3.13)
project(uWebSockets LANGUAGES C CXX)

set(UWEBSOCKETS_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/extern/uWebSockets)

# Include directories
include_directories(${UWEBSOCKETS_SOURCE_DIR}/src)
include_directories(${UWEBSOCKETS_SOURCE_DIR}/uSockets/src)
include_directories(${LIBUV_INCLUDE_DIR})

# Add the uWebSockets interface library
add_library(uWS INTERFACE)

# Set C++20 standard for uWS target
target_compile_features(uWS INTERFACE cxx_std_20)

# Link uSockets library
target_link_libraries(uWS INTERFACE uSockets)

# Add options for different features
option(WITH_LIBDEFLATE "Build with libdeflate support" OFF)
option(WITH_ZLIB "Build with zlib support" ON)
option(WITH_PROXY "Build with PROXY Protocol v2 support" OFF)
option(WITH_QUIC "Build with QUIC support" OFF)
option(WITH_BORINGSSL "Build with BoringSSL support" OFF)
option(WITH_OPENSSL "Build with OpenSSL support" OFF)
option(WITH_WOLFSSL "Build with WolfSSL support" OFF)
option(WITH_LIBUV "Build with libuv support" ON)
option(WITH_ASIO "Build with ASIO support" OFF)
option(WITH_ASAN "Build with AddressSanitizer support" OFF)

if(WITH_LIBDEFLATE)
    target_compile_definitions(uWS INTERFACE UWS_USE_LIBDEFLATE)
    target_include_directories(uWS INTERFACE ${UWEBSOCKETS_SOURCE_DIR}/libdeflate)
    if(MSVC)
        target_link_libraries(uWS INTERFACE ${UWEBSOCKETS_SOURCE_DIR}/libdeflate/libdeflate.lib)
    else()
        target_link_libraries(uWS INTERFACE ${UWEBSOCKETS_SOURCE_DIR}/libdeflate/libdeflate.a)
    endif()
endif()

if(WITH_ZLIB)
    target_include_directories(uWS INTERFACE ${ZLIB_INCLUDE_DIRS})
    target_link_libraries(uWS INTERFACE ${ZLIB_LIBRARIES})
else()
    target_compile_definitions(uWS INTERFACE UWS_NO_ZLIB)
endif()

if(WITH_PROXY)
    target_compile_definitions(uWS INTERFACE UWS_WITH_PROXY)
endif()

if(WITH_QUIC)
    target_compile_definitions(uWS INTERFACE LIBUS_USE_QUIC)
    if(MSVC)
        target_link_libraries(uWS INTERFACE ${UWEBSOCKETS_SOURCE_DIR}/uSockets/lsquic/src/liblsquic/liblsquic.lib)
    else()
        target_link_libraries(uWS INTERFACE pthread z m ${UWEBSOCKETS_SOURCE_DIR}/uSockets/lsquic/src/liblsquic/liblsquic.a)
    endif()
endif()

if(WITH_BORINGSSL OR WITH_OPENSSL)
    target_link_libraries(uWS INTERFACE ssl crypto)
elseif(WITH_WOLFSSL)
    target_compile_definitions(uWS INTERFACE LIBUS_USE_WOLFSSL)
    target_compile_definitions(uWS INTERFACE OPENSSL_EXTRA OPENSSL_ALL HAVE_SNI TLS13 HAVE_DTLS)
    target_include_directories(uWS INTERFACE ${WOLFSSL_INCLUDE_DIR})
    target_link_libraries(uWS INTERFACE ${WOLFSSL_LIBRARY})
endif()

if(WITH_LIBUV)
    target_include_directories(uWS INTERFACE ${LIBUV_INCLUDE_DIR})
    target_link_libraries(uWS INTERFACE ${LIBUV_LIBRARY})
endif()

if(WITH_ASIO)
    if(NOT MSVC)
        target_compile_options(uWS INTERFACE -pthread)
        target_link_libraries(uWS INTERFACE pthread)
    endif()
endif()

if(WITH_ASAN)
    if(MSVC)
        target_compile_options(uWS INTERFACE /fsanitize=address /Zi)
    else()
        target_compile_options(uWS INTERFACE -fsanitize=address -g)
        target_link_libraries(uWS INTERFACE asan)
    endif()
endif()
