add_library(Lute.CLI.Commands STATIC)

target_sources(Lute.CLI.Commands PRIVATE
    generated/commands.h
    generated/commands.cpp

    include/lute/clicommands.h
    src/clicommands.cpp
)

target_compile_features(Lute.CLI.Commands PUBLIC cxx_std_17)
target_include_directories(Lute.CLI.Commands PUBLIC include generated)
target_compile_options(Lute.CLI.Commands PRIVATE ${LUTE_OPTIONS})

add_library(Lute.CLI.lib STATIC)

target_sources(Lute.CLI.lib PRIVATE
    include/lute/climain.h
    include/lute/compile.h
    include/lute/tc.h

    src/climain.cpp
    src/compile.cpp
    src/tc.cpp
)

target_compile_features(Lute.CLI.lib PUBLIC cxx_std_17)
target_include_directories(Lute.CLI.lib PUBLIC include)
target_link_libraries(Lute.CLI.lib PRIVATE Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.CLI.Commands Lute.Require Lute.Runtime Luau.CLI.lib)
target_compile_options(Lute.CLI.lib PRIVATE ${LUTE_OPTIONS})

add_executable(Lute.CLI)

target_sources(Lute.CLI PRIVATE
    src/main.cpp
)

set_target_properties(Lute.CLI PROPERTIES OUTPUT_NAME lute)
target_compile_features(Lute.CLI PUBLIC cxx_std_17)
target_link_libraries(Lute.CLI PRIVATE Lute.CLI.lib)
target_compile_options(Lute.CLI PRIVATE ${LUTE_OPTIONS})
