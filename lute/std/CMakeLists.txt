set(STD_GENERATED_HEADER ${CMAKE_CURRENT_BINARY_DIR}/generated/lute_std_files.h)

embed_files(
    OUTPUT_HEADER   ${STD_GENERATED_HEADER}
    VARIABLE_NAME   "LUTE_STD"
    ROOT_DIR        "${CMAKE_CURRENT_SOURCE_DIR}/libs"
    INPUT_FILES     "${CMAKE_CURRENT_SOURCE_DIR}/libs"
    PATH_PREFIX     "@std/"
)

add_library(Lute.Std STATIC)

target_sources(Lute.Std PRIVATE
    include/lute/stdlib.h
    src/stdlib.cpp

    ${STD_GENERATED_HEADER}
)

target_compile_features(Lute.Std PUBLIC cxx_std_17)
target_include_directories(Lute.Std PUBLIC "include" "${CMAKE_CURRENT_BINARY_DIR}/generated")
target_link_libraries(Lute.Std PRIVATE Lute.Runtime Luau.VM uv_a)
target_compile_options(Lute.Std PRIVATE ${LUTE_OPTIONS})
