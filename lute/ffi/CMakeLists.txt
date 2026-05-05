add_library(Lute.FFI STATIC)

target_sources(Lute.FFI PRIVATE
    include/lute/ffi.h

    src/ffi.cpp
    src/c.cpp
)

target_compile_features(Lute.FFI PUBLIC cxx_std_17)
target_include_directories(Lute.FFI PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.FFI PRIVATE Lute.Runtime Luau.VM uv_a libffi)
target_compile_options(Lute.FFI PRIVATE ${LUTE_OPTIONS})
