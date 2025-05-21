add_executable(Lute.Test)

target_sources(Lute.Test PRIVATE
	include/doctest.h

    src/main.cpp
    src/require.test.cpp
)

set_target_properties(Lute.Test PROPERTIES OUTPUT_NAME lute-tests)
include_directories(Lute.Test
	include
)
target_link_libraries(Lute.Test PRIVATE Luau.CLI.lib Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.Runtime Lute.Crypto Lute.Fs Lute.Luau Lute.Net Lute.Task Lute.VM Lute.Process Lute.System Lute.Time)
target_compile_options(Lute.Test PRIVATE ${LUTE_OPTIONS})
