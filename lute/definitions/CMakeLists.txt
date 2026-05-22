add_library(Lute.Lute STATIC)

if (LUTE_STDLESS)
    target_sources(Lute.Lute PRIVATE
        include/lute/lutemodules.h
        src/lutemodules_stub.cpp
    )
else()
    target_sources(Lute.Lute PRIVATE
        include/lute/lutemodules.h
        src/lutemodules.cpp
        src/generated/modules.h
        src/generated/modules.cpp
    )
endif()

target_compile_features(Lute.Lute PUBLIC cxx_std_17)
target_include_directories(Lute.Lute PUBLIC "include")
target_compile_options(Lute.Lute PRIVATE ${LUTE_OPTIONS})
