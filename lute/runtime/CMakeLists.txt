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
target_link_libraries(Lute.Runtime PRIVATE Lute.Crypto Lute.Fs Lute.Luau Lute.Net Lute.Task Lute.VM Lute.Process Lute.System Lute.Time Luau.Common Luau.Require Luau.VM uv_a)
target_compile_options(Lute.Runtime PRIVATE ${LUTE_OPTIONS})
