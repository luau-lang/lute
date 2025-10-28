add_executable(Lute.Test)

target_sources(Lute.Test PRIVATE
    src/doctest.h
    src/main.cpp
    src/cliruntimefixture.h
    src/cliruntimefixture.cpp

    src/luteprojectroot.h
    src/luteprojectroot.cpp

    src/modulepath.test.cpp
    src/require.test.cpp
    src/stdsystem.test.cpp
    src/staticrequires.test.cpp
    src/stdsystem.test.cpp
    src/compile.test.cpp)

set_target_properties(Lute.Test PROPERTIES OUTPUT_NAME lute-tests)
target_compile_features(Lute.Test PUBLIC cxx_std_17)
target_link_libraries(Lute.Test PRIVATE Lute.CLI.lib Lute.Require Lute.Runtime Luau.CLI.lib Luau.Compiler Luau.VM)
target_compile_options(Lute.Test PRIVATE ${LUTE_OPTIONS})
