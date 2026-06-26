add_library(Lute.Debug STATIC)

target_sources(Lute.Debug PRIVATE
    src/debugger.h
    src/debugger.cpp
)

target_compile_features(Lute.Debug PUBLIC cxx_std_17)
target_include_directories(Lute.Debug
    PUBLIC src
)
target_link_libraries(Lute.Debug
    PUBLIC Lute.Runtime
    PRIVATE Luau.Compiler Luau.VM
)
target_compile_options(Lute.Debug PRIVATE ${LUTE_OPTIONS})
