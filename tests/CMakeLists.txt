add_executable(Lute.Test)

target_sources(Lute.Test PRIVATE
    src/doctest.h
    src/main.cpp

    src/require.test.cpp)

set_target_properties(Lute.Test PROPERTIES OUTPUT_NAME lute-tests)
target_compile_features(Lute.Test PUBLIC cxx_std_17)
target_link_libraries(Lute.Test PRIVATE Lute.Require Luau.CLI.lib)
target_compile_options(Lute.Test PRIVATE ${LUTE_OPTIONS})
