add_executable(Lute.CLI)

target_sources(Lute.CLI PRIVATE
    src/main.cpp
    src/compile.h
    src/compile.cpp
    src/tc.h
    src/tc.cpp
)

set_target_properties(Lute.CLI PROPERTIES OUTPUT_NAME lute)
target_compile_features(Lute.CLI PUBLIC cxx_std_17)
target_link_libraries(Lute.CLI PRIVATE Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.CLI.Commands Lute.Runtime Lute.Crypto Lute.Fs Lute.Luau Lute.Net Lute.Task Lute.VM Lute.Process Lute.System Lute.Time Luau.CLI.lib)
target_compile_options(Lute.CLI PRIVATE ${LUTE_OPTIONS})


add_library(Lute.CLI.Commands STATIC)

target_sources(Lute.CLI.Commands PRIVATE
    generated/commands.h
    generated/commands.cpp

    clicommands.h
    clicommands.cpp
)

target_compile_features(Lute.CLI.Commands PUBLIC cxx_std_17)
target_include_directories(Lute.CLI.Commands PUBLIC "")
target_compile_options(Lute.CLI.Commands PRIVATE ${LUTE_OPTIONS})
