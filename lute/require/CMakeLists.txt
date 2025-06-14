add_library(Lute.Require)

target_sources(Lute.Require PRIVATE
    include/lute/clivfs.h
    include/lute/filevfs.h
    include/lute/modulepath.h
    include/lute/options.h
    include/lute/require.h
    include/lute/requirevfs.h
    include/lute/stdlibvfs.h

    src/clivfs.cpp
    src/filevfs.cpp
    src/modulepath.cpp
    src/options.cpp
    src/require.cpp
    src/requirevfs.cpp
    src/stdlibvfs.cpp
)

target_compile_features(Lute.Require PUBLIC cxx_std_17)
target_include_directories(Lute.Require PUBLIC include)
target_link_libraries(Lute.Require PUBLIC Luau.Require PRIVATE Luau.CLI.lib Luau.Compiler Luau.CodeGen Lute.Std Lute.CLI.Commands)
target_compile_options(Lute.Require PRIVATE ${LUTE_OPTIONS})
