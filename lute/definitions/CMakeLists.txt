add_library(Lute.Lute STATIC)

target_sources(Lute.Lute PRIVATE
    include/lute/lutemodules.h

    src/lutemodules.cpp
    src/generated/modules.h
    src/generated/modules.cpp
)

target_compile_features(Lute.Lute PUBLIC cxx_std_17)
target_include_directories(Lute.Lute PUBLIC "include")
target_link_libraries(Lute.Lute PRIVATE Lute.Common)
target_compile_options(Lute.Lute PRIVATE ${LUTE_OPTIONS})
