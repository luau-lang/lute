add_library(Lute.Process STATIC)

target_sources(Lute.Process PRIVATE
    include/lute/process.h

    src/process.cpp
)

target_compile_features(Lute.Process PUBLIC cxx_std_17)
target_include_directories(Lute.Process PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Process PRIVATE Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.Process PRIVATE ${LUTE_OPTIONS})
