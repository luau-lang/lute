cmake_minimum_required(VERSION 3.13)
project(uSockets LANGUAGES C CXX)

# Set the C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(USOCKETS_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/extern/uWebSockets/uSockets)

# Include directories
include_directories(${USOCKETS_SOURCE_DIR}/src)
include_directories(${USOCKETS_SOURCE_DIR}/src/eventing)
include_directories(${USOCKETS_SOURCE_DIR}/src/crypto)
include_directories(${USOCKETS_SOURCE_DIR}/src/io_uring)
include_directories(${LIBUV_INCLUDE_DIR})

# Options for crypto backends and other features
option(WITH_ASIO "Build with Boost Asio support" OFF)
option(WITH_OPENSSL "Build with OpenSSL support" OFF)
option(WITH_BORINGSSL "Build with BoringSSL support" OFF)
option(WITH_WOLFSSL "Build with WolfSSL support" OFF)
option(WITH_IO_URING "Build with io_uring support" OFF)
option(WITH_LIBUV "Build with libuv support" ON)
option(WITH_GCD "Build with libdispatch support" OFF)
option(WITH_ASAN "Build with AddressSanitizer support" OFF)
option(WITH_QUIC "Build with QUIC support" OFF)

# Source files — filter openssl.c if BoringSSL is used
file(GLOB USOCKETS_C_SRC
    ${USOCKETS_SOURCE_DIR}/src/*.c
    ${USOCKETS_SOURCE_DIR}/src/eventing/*.c
    ${USOCKETS_SOURCE_DIR}/src/io_uring/*.c
)

file(GLOB USOCKETS_CRYPTO_C_SRC
    ${USOCKETS_SOURCE_DIR}/src/crypto/*.c
)

file(GLOB USOCKETS_CRYPTO_CPP_SRC
    ${USOCKETS_SOURCE_DIR}/src/crypto/*.cpp
)

set(USOCKETS_SOURCES
    ${USOCKETS_C_SRC}
    ${USOCKETS_CRYPTO_C_SRC}
    ${USOCKETS_CRYPTO_CPP_SRC}
)

add_library(uSockets STATIC ${USOCKETS_SOURCES})
target_compile_features(uSockets PRIVATE cxx_std_17)

if(MSVC)
    target_compile_definitions(uSockets PRIVATE _HAS_CXX17=1)
    target_compile_options(uSockets PRIVATE /experimental:c11atomics)
endif()

# ASIO
if(WITH_ASIO)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_ASIO)
    if(MSVC)
        target_compile_options(uSockets PRIVATE /std:c++14)
        target_link_libraries(uSockets PRIVATE)
    else()
        target_compile_options(uSockets PRIVATE -std=c++14 -pthread)
        target_link_libraries(uSockets PRIVATE stdc++ pthread)
    endif()
endif()


# Crypto backend options
if(WITH_OPENSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
    target_link_libraries(uSockets PRIVATE ssl crypto stdc++)
endif()

if(WITH_BORINGSSL)
    set(BORINGSSL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/extern/boringssl")
    set(BORINGSSL_INCLUDE_DIR "${BORINGSSL_DIR}/include")
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
    target_compile_definitions(uSockets PRIVATE UWS_WITH_BORINGSSL)
    include_directories(uSockets PRIVATE ${BORINGSSL_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ssl crypto stdc++)
    # force openssl.c to compile with C++?
    if (MSVC)
        target_compile_definitions(uSockets PRIVATE alignas=alignas)
        set_source_files_properties(
            ${CMAKE_CURRENT_SOURCE_DIR}/extern/uWebSockets/uSockets/src/crypto/openssl.c
            PROPERTIES LANGUAGE CXX
        )
    endif()
endif()

if(WITH_WOLFSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_WOLFSSL)
    target_compile_definitions(uSockets PRIVATE OPENSSL_EXTRA OPENSSL_ALL HAVE_SNI TLS13 HAVE_DTLS)
    target_include_directories(uSockets PRIVATE ${WOLFSSL_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ${WOLFSSL_LIBRARY})
endif()

# io_uring
if(WITH_IO_URING)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_IO_URING)
    if(NOT MSVC)
        target_link_libraries(uSockets PRIVATE /usr/lib/liburing.a)
    endif()
endif()

# libuv
if(WITH_LIBUV)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_LIBUV)
    target_include_directories(uSockets PRIVATE ${LIBUV_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ${LIBUV_LIBRARY})
endif()

# GCD (Apple)
if(WITH_GCD)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_GCD)
    target_link_libraries(uSockets PRIVATE CoreFoundation)
endif()

# ASAN
if(WITH_ASAN)
    if(MSVC)
        target_compile_options(uSockets PRIVATE /fsanitize=address /Zi)
    else()
        target_compile_options(uSockets PRIVATE -fsanitize=address -g)
        target_link_libraries(uSockets PRIVATE asan)
    endif()
endif()

# QUIC
if(WITH_QUIC)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_QUIC)
    target_include_directories(uSockets PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/lsquic/include)
    if(MSVC)
        target_link_libraries(uSockets PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/lsquic/src/liblsquic/liblsquic.lib)
    else()
        target_link_libraries(uSockets PRIVATE pthread z m ${CMAKE_CURRENT_SOURCE_DIR}/lsquic/src/liblsquic/liblsquic.a)
    endif()
endif()
