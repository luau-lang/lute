add_library(Lute.Luau STATIC)

target_sources(Lute.Luau PRIVATE
    include/lute/luau.h

    src/luau.cpp
)

target_compile_features(Lute.Luau PUBLIC cxx_std_17)
target_include_directories(Lute.Luau PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Luau PRIVATE Lute.Runtime Luau.VM uv_a Luau.Analysis Luau.Ast Luau.Compiler)
target_compile_options(Lute.Luau PRIVATE ${LUTE_OPTIONS})
