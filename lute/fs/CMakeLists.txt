add_library(Lute.Fs STATIC)

target_sources(Lute.Fs PRIVATE
    include/lute/fs.h

    src/fs.cpp
    src/fs_impl.h
    src/fs_impl.cpp
)

target_compile_features(Lute.Fs PUBLIC cxx_std_17)
target_include_directories(Lute.Fs PUBLIC "include")
target_link_libraries(Lute.Fs PRIVATE Lute.Runtime Lute.Time libuv::libuv PUBLIC Lute.Common)
target_compile_options(Lute.Fs PRIVATE ${LUTE_OPTIONS})
