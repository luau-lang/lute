add_library(Lute.Luau STATIC)

target_sources(Lute.Luau PRIVATE
    include/lute/luau.h
    include/lute/staticrequire.h

    src/luau.cpp
    src/staticrequire.cpp
)

target_compile_features(Lute.Luau PUBLIC cxx_std_17)
target_include_directories(Lute.Luau PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Luau PRIVATE Lute.Require Lute.Runtime uv_a Luau.Analysis Luau.Ast Luau.Compiler Luau.RequireNavigator Luau.VM)
target_compile_options(Lute.Luau PRIVATE ${LUTE_OPTIONS})
