add_library(Lute.Batteries STATIC)

target_sources(Lute.Batteries PRIVATE
    generated/batteries.h
    generated/batteries.cpp

    include/lute/clibatteries.h
    src/clibatteries.cpp
)

target_compile_features(Lute.Batteries PUBLIC cxx_std_17)
target_include_directories(Lute.Batteries PUBLIC include generated)
target_link_libraries(Lute.Batteries PRIVATE Lute.Common uv_a)
target_compile_options(Lute.Batteries PRIVATE ${LUTE_OPTIONS})

set(BATTERIES_GENERATED_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${BATTERIES_GENERATED_INCLUDE_DIR}/lute")

