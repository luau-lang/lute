add_library(Lute.Task STATIC)

target_sources(Lute.Task PRIVATE
    include/lute/task.h

    src/task.cpp
)

target_compile_features(Lute.Task PUBLIC cxx_std_17)
target_include_directories(Lute.Task PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Task PRIVATE Lute.Runtime Lute.Time Luau.VM uv_a)
target_compile_options(Lute.Task PRIVATE ${LUTE_OPTIONS})
