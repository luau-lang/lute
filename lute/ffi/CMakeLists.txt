add_library(Lute.FFI STATIC)

target_sources(Lute.FFI PRIVATE
    include/lute/ffi.h
    
    src/c/module.cpp
    src/c/library.cpp

    src/c/types/functions.cpp
    src/c/types/primitives.cpp
    src/c/types/structs.cpp
    src/c/types/constants.cpp

    src/c/types/primitives.h
    src/c/types/functions.h
    src/c/types/structs.h
    src/c/types/constants.h

    src/c/ctype.h
    src/c/callstate.h
    src/c/library.h

    src/ffi.cpp
)

target_compile_features(Lute.FFI PUBLIC cxx_std_17)
target_include_directories(Lute.FFI PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_include_directories(Lute.FFI PRIVATE "src/c")
target_link_libraries(Lute.FFI PRIVATE Lute.Runtime Luau.VM uv_a libffi)
target_compile_options(Lute.FFI PRIVATE ${LUTE_OPTIONS})
