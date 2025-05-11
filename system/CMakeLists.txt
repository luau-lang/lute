add_library(Lute.System STATIC)

target_sources(Lute.System PRIVATE
    include/lute/system.h

    src/system.cpp
)

target_compile_features(Lute.System PUBLIC cxx_std_17)
target_include_directories(Lute.System PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.System PRIVATE Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.System PRIVATE ${LUTE_OPTIONS})
