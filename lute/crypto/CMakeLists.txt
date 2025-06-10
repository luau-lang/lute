add_library(Lute.Crypto STATIC)

target_sources(Lute.Crypto PRIVATE
    include/lute/crypto.h

    src/crypto.cpp
)

target_compile_features(Lute.Crypto PUBLIC cxx_std_17)
target_include_directories(Lute.Crypto PUBLIC "include" ${LIBUV_INCLUDE_DIR})
target_link_libraries(Lute.Crypto PRIVATE Lute.Runtime Luau.VM uv_a ssl crypto sodium)
target_compile_options(Lute.Crypto PRIVATE ${LUTE_OPTIONS})
