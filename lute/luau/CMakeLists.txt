add_library(Lute.Luau STATIC)

target_sources(Lute.Luau PRIVATE
    include/lute/configresolver.h
    include/lute/luau.h
    include/lute/tcmoduleresolver.h
    include/lute/tcreporter.h
    include/lute/resolvemodule.h
    include/lute/type.h

    src/configresolver.cpp
    src/luau.cpp
    src/tcmoduleresolver.cpp
    src/resolvemodule.cpp
    src/type.cpp
)

target_compile_features(Lute.Luau PUBLIC cxx_std_17)
target_include_directories(Lute.Luau PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Luau PRIVATE Lute.Common Lute.Require Lute.Runtime uv_a Luau.Analysis Luau.Ast Luau.Compiler Luau.CLI.lib Luau.Require Luau.VM)
target_compile_options(Lute.Luau PRIVATE ${LUTE_OPTIONS})
