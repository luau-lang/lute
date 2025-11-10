add_library(Lute.IO STATIC)

target_sources(Lute.IO PRIVATE
    include/lute/io.h

    src/io.cpp
)

target_compile_features(Lute.IO PUBLIC cxx_std_17)
target_include_directories(Lute.IO PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.IO PRIVATE Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.IO PRIVATE ${LUTE_OPTIONS})
