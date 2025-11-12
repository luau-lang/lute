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

set(CLI_GENERATED_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${CLI_GENERATED_INCLUDE_DIR}/lute")
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/include/lute/version.h.in
    ${CLI_GENERATED_INCLUDE_DIR}/lute/version.h
    @ONLY
)

add_library(Lute.CLI.lib STATIC)

target_sources(Lute.CLI.lib PRIVATE
    include/lute/climain.h
    include/lute/compile.h
    include/lute/luauflags.h
    include/lute/reporter.h
    include/lute/staticrequires.h
    include/lute/tc.h
    include/lute/uvstate.h

    src/climain.cpp
    src/compile.cpp
    src/luauflags.cpp
    src/staticrequires.cpp
    src/tc.cpp
    src/uvstate.cpp
)

target_compile_features(Lute.CLI.lib PUBLIC cxx_std_17)
target_include_directories(Lute.CLI.lib PUBLIC include ${CLI_GENERATED_INCLUDE_DIR} ${ZLIB_INCLUDE_DIR})
target_link_libraries(Lute.CLI.lib PRIVATE Luau.Common Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.CLI.Commands Lute.Crypto Lute.Fs Lute.IO Lute.Luau Lute.Net Lute.Task Lute.VM Lute.Process Lute.System Lute.Time Lute.Require Lute.Runtime Luau.CLI.lib zlibstatic)
target_compile_options(Lute.CLI.lib PRIVATE ${LUTE_OPTIONS})

add_executable(Lute.CLI)

target_sources(Lute.CLI PRIVATE
    include/lute/clireporter.h

    src/clireporter.cpp
    src/main.cpp
)

set_target_properties(Lute.CLI PROPERTIES OUTPUT_NAME lute)
target_compile_features(Lute.CLI PUBLIC cxx_std_17)
target_link_libraries(Lute.CLI PRIVATE Lute.CLI.lib)
target_compile_options(Lute.CLI PRIVATE ${LUTE_OPTIONS})
