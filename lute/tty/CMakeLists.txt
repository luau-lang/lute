add_library(Lute.Tty STATIC)

target_sources(Lute.Tty PRIVATE
    include/lute/tty.h

    src/tty.cpp
)

target_compile_features(Lute.Tty PUBLIC cxx_std_17)
target_include_directories(Lute.Tty PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Tty PRIVATE Lute.Common Lute.Process Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.Tty PRIVATE ${LUTE_OPTIONS})
