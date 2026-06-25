add_library(Lute.Debug STATIC)

target_sources(Lute.Debug PRIVATE
    src/debugger.h
    src/debugger.cpp
    ${CMAKE_SOURCE_DIR}/lute/cli/src/clireporter.cpp
)

target_compile_features(Lute.Debug PUBLIC cxx_std_17)
target_include_directories(Lute.Debug
    PUBLIC src
    PRIVATE ${CMAKE_SOURCE_DIR}/lute/cli/include
)
target_link_libraries(Lute.Debug
    PUBLIC Lute.Runtime
    PRIVATE Luau.Compiler Luau.VM
)
target_compile_options(Lute.Debug PRIVATE ${LUTE_OPTIONS})
