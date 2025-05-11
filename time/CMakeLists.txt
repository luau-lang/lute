add_library(Lute.Time STATIC)

target_sources(Lute.Time PRIVATE
    include/lute/time.h

    src/time.cpp
)

target_compile_features(Lute.Time PUBLIC cxx_std_17)
target_include_directories(Lute.Time PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Time PRIVATE Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.Time PRIVATE ${LUTE_OPTIONS})
