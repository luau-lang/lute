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

# Source files
file(GLOB USOCKETS_SOURCES 
    ${USOCKETS_SOURCE_DIR}/src/*.c 
    ${USOCKETS_SOURCE_DIR}/src/eventing/*.c 
    ${USOCKETS_SOURCE_DIR}/src/crypto/*.c 
    ${USOCKETS_SOURCE_DIR}/src/crypto/*.cpp
    ${USOCKETS_SOURCE_DIR}/src/io_uring/*.c
)

# Add the uSockets library
add_library(uSockets STATIC ${USOCKETS_SOURCES})

# Set C++17 standard for uSockets target (only affects .cpp files)
target_compile_features(uSockets PRIVATE cxx_std_17)

if(MSVC)
  target_compile_definitions(uSockets PRIVATE _HAS_CXX17=1)
  target_compile_options(uSockets PRIVATE /experimental:c11atomics)
endif()

# Add options for different features
option(WITH_ASIO "Build with Boost Asio support" OFF)
option(WITH_OPENSSL "Build with OpenSSL support" OFF)
option(WITH_BORINGSSL "Build with BoringSSL support" OFF)
option(WITH_WOLFSSL "Build with WolfSSL support" OFF)
option(WITH_IO_URING "Build with io_uring support" OFF)
option(WITH_LIBUV "Build with libuv support" ON)
option(WITH_GCD "Build with libdispatch support" OFF)
option(WITH_ASAN "Build with AddressSanitizer support" OFF)
option(WITH_QUIC "Build with QUIC support" OFF)

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

if(WITH_OPENSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
    target_link_libraries(uSockets PRIVATE ssl crypto stdc++)
endif()

if(WITH_BORINGSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
    target_include_directories(uSockets PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/boringssl/include)
    if(MSVC)
        target_link_libraries(uSockets PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/boringssl/build/ssl/ssl.lib ${CMAKE_CURRENT_SOURCE_DIR}/boringssl/build/crypto/crypto.lib)
    else()
        target_link_libraries(uSockets PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/boringssl/build/ssl/libssl.a ${CMAKE_CURRENT_SOURCE_DIR}/boringssl/build/crypto/libcrypto.a pthread stdc++)
    endif()
endif()

if(WITH_WOLFSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_WOLFSSL)
    target_compile_definitions(uSockets PRIVATE OPENSSL_EXTRA OPENSSL_ALL HAVE_SNI TLS13 HAVE_DTLS)
    target_include_directories(uSockets PRIVATE ${WOLFSSL_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ${WOLFSSL_LIBRARY})
endif()

if(WITH_IO_URING)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_IO_URING)
    if(NOT MSVC) # io_uring is Linux-specific
        target_link_libraries(uSockets PRIVATE /usr/lib/liburing.a)
    endif()
endif()

if(WITH_LIBUV)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_LIBUV)
    target_include_directories(uSockets PRIVATE ${LIBUV_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ${LIBUV_LIBRARY})
endif()

if(WITH_GCD)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_GCD)
    target_link_libraries(uSockets PRIVATE CoreFoundation)
endif()

if(WITH_ASAN)
    if(MSVC)
        target_compile_options(uSockets PRIVATE /fsanitize=address /Zi)
    else()
        target_compile_options(uSockets PRIVATE -fsanitize=address -g)
        target_link_libraries(uSockets PRIVATE asan)
    endif()
endif()

if(WITH_QUIC)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_QUIC)
    target_include_directories(uSockets PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/lsquic/include)
    if(MSVC)
        target_link_libraries(uSockets PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/lsquic/src/liblsquic/liblsquic.lib)
    else()
        target_link_libraries(uSockets PRIVATE pthread z m ${CMAKE_CURRENT_SOURCE_DIR}/lsquic/src/liblsquic/liblsquic.a)
    endif()
endif()
