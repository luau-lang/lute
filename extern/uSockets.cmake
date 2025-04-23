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

file(GLOB USOCKETS_C_SRC
    ${USOCKETS_SOURCE_DIR}/src/*.c
    ${USOCKETS_SOURCE_DIR}/src/crypto/*.c
    ${USOCKETS_SOURCE_DIR}/src/eventing/*.c
    ${USOCKETS_SOURCE_DIR}/src/io_uring/*.c
)

file(GLOB USOCKETS_CXX_SRC
    ${USOCKETS_SOURCE_DIR}/src/crypto/sni_tree.cpp
)

add_library(uSockets STATIC ${USOCKETS_C_SRC} ${USOCKETS_CXX_SRC})

if(MSVC)
    target_compile_definitions(uSockets PRIVATE _HAS_CXX17=1)
    target_compile_options(uSockets PRIVATE /experimental:c11atomics)
endif()

# Crypto backend options
if(WITH_OPENSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
    target_link_libraries(uSockets PRIVATE ssl crypto stdc++)
endif()

if(WITH_BORINGSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
    target_compile_definitions(uSockets PRIVATE UWS_WITH_BORINGSSL)
    target_link_libraries(uSockets PRIVATE ssl crypto)

    # we need to compile openssl in C++ mode with MSVC, but we also have to apply a patch to the file.
    if (MSVC)
        set_source_files_properties(
            ${USOCKETS_SOURCE_DIR}/src/crypto/openssl.c
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

# libuv
if(WITH_LIBUV)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_LIBUV)
    target_include_directories(uSockets PRIVATE ${LIBUV_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ${LIBUV_LIBRARY})
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
