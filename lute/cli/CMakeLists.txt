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
    include/lute/coverage.h
    include/lute/luauflags.h
    include/lute/packagerun.h
    include/lute/profiler.h
    include/lute/requiresetup.h
    include/lute/staticrequires.h
    include/lute/tc.h
    include/lute/uvstate.h

    src/climain.cpp
    src/compile.cpp
    src/coverage.cpp
    src/luauflags.cpp
    src/packagerun.cpp
    src/profiler.cpp
    src/requiresetup.cpp
    src/staticrequires.cpp
    src/tc.cpp
    src/uvstate.cpp
)

target_compile_features(Lute.CLI.lib PUBLIC cxx_std_17)
target_include_directories(Lute.CLI.lib PUBLIC include ${CLI_GENERATED_INCLUDE_DIR} ${ZLIB_INCLUDE_DIR})
target_link_libraries(Lute.CLI.lib PRIVATE Luau.Common Luau.Compiler Luau.Config Luau.CodeGen Luau.Analysis Luau.VM Lute.CLI.Commands Lute.Luau Lute.Process Lute.Require Lute.Runtime Luau.CLI.lib Lute.Common zlibstatic)
target_compile_options(Lute.CLI.lib PRIVATE ${LUTE_OPTIONS})

add_executable(Lute.CLI)

target_sources(Lute.CLI PRIVATE
    include/lute/clireporter.h

    src/clireporter.cpp
    src/main.cpp
)

set_target_properties(Lute.CLI PROPERTIES OUTPUT_NAME lute)
target_compile_features(Lute.CLI PUBLIC cxx_std_17)
target_link_libraries(Lute.CLI PRIVATE Lute.CLI.lib Lute.Common)
target_compile_options(Lute.CLI PRIVATE ${LUTE_OPTIONS})

if (LUTE_OPTIMIZE_SIZE AND NOT LUTE_ENABLE_SANITIZERS AND NOT MSVC AND CMAKE_STRIP)
    if (APPLE)
        # -x keeps dynamic symbols so dladdr backtraces still work.
        set(_lute_strip_args -x)
    else()
        set(_lute_strip_args "")
    endif()
    add_custom_command(TARGET Lute.CLI POST_BUILD
        COMMAND "$<IF:$<CONFIG:Debug>,true,${CMAKE_STRIP}>" ${_lute_strip_args} "$<TARGET_FILE:Lute.CLI>"
        COMMENT "Stripping symbols from $<TARGET_FILE_NAME:Lute.CLI> (skipped in Debug)"
        VERBATIM
    )
endif()
