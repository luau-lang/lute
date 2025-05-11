add_library(Lute.Runtime)

target_sources(Lute.Runtime PRIVATE
    include/lute/options.h
    include/lute/ref.h
    include/lute/require.h
    include/lute/requireutils.h
    include/lute/runtime.h
    include/lute/userdatas.h

    src/options.cpp
    src/ref.cpp
    src/require.cpp
    src/requireutils.cpp
    src/runtime.cpp
)

target_compile_features(Lute.Runtime PUBLIC cxx_std_17)
target_include_directories(Lute.Runtime PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Runtime PUBLIC Luau.Require PRIVATE Luau.CLI.lib Luau.Compiler Luau.Config Luau.CodeGen Luau.VM Lute.Std uv_a)
target_compile_options(Lute.Runtime PRIVATE ${LUTE_OPTIONS})
