add_library(Lute.Debug STATIC)

target_sources(Lute.Debug PRIVATE
    include/lute/debug.h
    include/lute/debuginternals.h

    src/debuginternals.cpp
    src/debug.cpp
)

target_compile_features(Lute.Debug PUBLIC cxx_std_17)
target_include_directories(Lute.Debug PUBLIC "include" PRIVATE src)
target_link_libraries(Lute.Debug
    PUBLIC Lute.Runtime
    PRIVATE Luau.Compiler Luau.VM Luau.Common
)
target_compile_options(Lute.Debug PRIVATE ${LUTE_OPTIONS})
