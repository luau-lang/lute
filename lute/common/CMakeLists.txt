add_library(Lute.Common STATIC)

target_sources(Lute.Common PRIVATE
    include/lute/fileutils.h

    src/fileutils.cpp
)

target_compile_features(Lute.Common PUBLIC cxx_std_17)
target_include_directories(Lute.Common PUBLIC include)
target_link_libraries(Lute.Common PRIVATE Luau.CLI.lib)
target_compile_options(Lute.Common PRIVATE ${LUTE_OPTIONS})
