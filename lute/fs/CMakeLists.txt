add_library(Lute.Fs STATIC)

target_sources(Lute.Fs PRIVATE
    include/lute/fs.h

    src/fs.cpp
)

target_compile_features(Lute.Fs PUBLIC cxx_std_17)
target_include_directories(Lute.Fs PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Fs PRIVATE Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.Fs PRIVATE ${LUTE_OPTIONS})
