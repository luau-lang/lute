add_library(Lute.Std STATIC)

if (LUTE_STDLESS)
    target_sources(Lute.Std PRIVATE
        include/lute/stdlib.h
        src/stdlib_stub.cpp
    )
else()
    target_sources(Lute.Std PRIVATE
        include/lute/stdlib.h
        src/stdlib.cpp
        src/generated/modules.h
        src/generated/modules.cpp
    )
endif()

target_compile_features(Lute.Std PUBLIC cxx_std_17)
target_include_directories(Lute.Std PUBLIC "include")
target_link_libraries(Lute.Std PRIVATE Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.Std PRIVATE ${LUTE_OPTIONS})
