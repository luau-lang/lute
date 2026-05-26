add_library(Lute.Require)

target_sources(Lute.Require PRIVATE
    include/lute/batteriesvfs.h
    include/lute/bundlevfs.h
    include/lute/clivfs.h
    include/lute/filevfs.h
    include/lute/lutevfs.h
    include/lute/modulepath.h
    include/lute/options.h
    include/lute/packagerequirevfs.h
    include/lute/require.h
    include/lute/requirevfs.h
    include/lute/stdlibvfs.h
    include/lute/userlandvfs.h

    src/batteriesvfs.cpp
    src/bundlevfs.cpp
    src/clivfs.cpp
    src/filevfs.cpp
    src/lutevfs.cpp
    src/modulepath.cpp
    src/options.cpp
    src/packagerequirevfs.cpp
    src/require.cpp
    src/requirevfs.cpp
    src/stdlibvfs.cpp
    src/userlandvfs.cpp
)

target_compile_features(Lute.Require PUBLIC cxx_std_17)
target_include_directories(Lute.Require PUBLIC include)
target_link_libraries(Lute.Require PUBLIC Luau.Require PRIVATE Luau.CLI.lib Luau.Compiler Luau.CodeGen Lute.Common Lute.Std Lute.CLI.Commands Lute.Batteries Lute.Std Lute.Lute Lute.Crypto Lute.Fs Lute.IO Lute.Luau Lute.Net Lute.Task Lute.Tty Lute.VM Lute.Process Lute.System Lute.Time Lute.Runtime)
target_compile_options(Lute.Require PRIVATE ${LUTE_OPTIONS})
