add_library(Lute.Runtime)

target_sources(Lute.Runtime PRIVATE
    include/lute/ref.h
    include/lute/runtime.h
    include/lute/userdatas.h

    src/ref.cpp
    src/runtime.cpp
)

target_compile_features(Lute.Runtime PUBLIC cxx_std_17)
target_include_directories(Lute.Runtime PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Runtime PRIVATE Luau.Common Luau.VM uv_a)
target_compile_options(Lute.Runtime PRIVATE ${LUTE_OPTIONS})
