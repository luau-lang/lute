add_executable(Lute.CLI)

target_sources(Lute.CLI PRIVATE
    src/main.cpp
    src/tc.h
    src/tc.cpp
)

set_target_properties(Lute.CLI PROPERTIES OUTPUT_NAME lute)
target_link_libraries(Lute.CLI PRIVATE Luau.CLI.lib Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.Runtime Lute.Crypto Lute.Fs Lute.Luau Lute.Net Lute.Task Lute.VM Lute.Process Lute.System Lute.Time)
target_compile_options(Lute.CLI PRIVATE ${LUTE_OPTIONS})
