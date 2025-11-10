add_executable(Lute.Test)

target_sources(Lute.Test PRIVATE
    src/doctest.h
    src/main.cpp

    # Test fixtures and utilities
    src/cliruntimefixture.h
    src/lutefixture.h
    src/luteprojectroot.h
    src/testreporter.h

    src/cliruntimefixture.cpp
    src/lutefixture.cpp
    src/luteprojectroot.cpp
    src/testreporter.cpp

    # Test files
    src/compile.test.cpp
    src/configresolver.test.cpp
    src/libraryrequire.test.cpp
    src/modulepath.test.cpp
    src/moduleresolver.test.cpp
    src/require.test.cpp
    src/staticrequires.test.cpp
    src/stdsystem.test.cpp)

set_target_properties(Lute.Test PROPERTIES OUTPUT_NAME lute-tests)
target_compile_features(Lute.Test PUBLIC cxx_std_17)
target_link_libraries(Lute.Test PRIVATE Lute.CLI.lib Lute.Luau Lute.Require Lute.Runtime Luau.CLI.lib Luau.Analysis Luau.Compiler Luau.VM)
target_compile_options(Lute.Test PRIVATE ${LUTE_OPTIONS})
