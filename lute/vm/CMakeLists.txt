add_library(Lute.VM STATIC)

target_sources(Lute.VM PRIVATE
    include/lute/spawn.h
    include/lute/vm.h

    src/spawn.cpp
    src/vm.cpp
)

target_compile_features(Lute.VM PUBLIC cxx_std_17)
target_include_directories(Lute.VM PUBLIC "include")
target_link_libraries(Lute.VM PRIVATE Lute.Require Lute.Runtime Luau.Require Luau.CodeGen libuv::libuv PUBLIC Lute.Common)
target_compile_options(Lute.VM PRIVATE ${LUTE_OPTIONS})
