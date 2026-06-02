add_library(Lute.Syntax STATIC)

target_sources(Lute.Syntax PRIVATE

    include/lute/syntax.h

    src/syntax.cpp
)

target_compile_features(Lute.Syntax PUBLIC cxx_std_17)
target_include_directories(Lute.Syntax PUBLIC "include")
target_link_libraries(Lute.Syntax PRIVATE Lute.Common Lute.Runtime Luau.VM)
target_compile_options(Lute.Syntax PRIVATE ${LUTE_OPTIONS})
