cmake_minimum_required(VERSION 3.13)
project(uSockets LANGUAGES C CXX)

# Set the C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(USOCKETS_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/extern/uSockets)

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
    target_compile_definitions(uSockets PRIVATE WIN32_LEAN_AND_MEAN)
    target_compile_definitions(uSockets PRIVATE NOMINMAX)
    target_compile_options(uSockets PRIVATE /experimental:c11atomics)
    target_compile_options(uSockets PRIVATE /GL-)
endif()

option(WITH_BORINGSSL "Build with BoringSSL support" OFF)
option(WITH_WOLFSSL "Build with WolfSSL support" OFF)
option(WITH_LIBUV "Build with libuv support" ON)
option(WITH_ASAN "Build with AddressSanitizer support" OFF)

if(WITH_BORINGSSL)
    target_include_directories(uSockets PRIVATE ${BORINGSSL_INCLUDE_DIR})
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
    target_link_libraries(uSockets PRIVATE ssl crypto)
endif()

if(WITH_WOLFSSL)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_WOLFSSL)
    target_compile_definitions(uSockets PRIVATE OPENSSL_EXTRA OPENSSL_ALL HAVE_SNI TLS13 HAVE_DTLS)
    target_include_directories(uSockets PRIVATE ${WOLFSSL_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ${WOLFSSL_LIBRARY})
endif()

if(WITH_LIBUV)
    target_compile_definitions(uSockets PRIVATE LIBUS_USE_LIBUV)
    target_include_directories(uSockets PRIVATE ${LIBUV_INCLUDE_DIR})
    target_link_libraries(uSockets PRIVATE ${LIBUV_LIBRARY})
endif()

if(WITH_ASAN)
    if(MSVC)
        target_compile_options(uSockets PRIVATE /fsanitize=address /Zi)
    else()
        target_compile_options(uSockets PRIVATE -fsanitize=address -g)
        target_link_libraries(uSockets PRIVATE asan)
    endif()
endif()
