cmake_minimum_required(VERSION 3.13)
project(hello-extension LANGUAGES CXX)

# Point at the Luau VM headers from the lute checkout
set(LUAU_VM_INCLUDE "${CMAKE_CURRENT_SOURCE_DIR}/../../extern/luau/VM/include")

add_library(hello SHARED hello.cpp)
target_include_directories(hello PRIVATE ${LUAU_VM_INCLUDE})
target_compile_features(hello PRIVATE cxx_std_17)

# On macOS, allow undefined symbols (resolved by the host lute binary at load time)
if(APPLE)
    target_link_options(hello PRIVATE -undefined dynamic_lookup)
elseif(WIN32)
    target_link_libraries(hello PRIVATE lute)
    target_compile_definitions(hello PRIVATE "LUA_API=__declspec(dllimport)")
endif()
