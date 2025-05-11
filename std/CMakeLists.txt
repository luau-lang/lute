file(GLOB LUAU_SOURCE_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/*.luau
)

set(GENERATED_HEADER ${CMAKE_CURRENT_BINARY_DIR}/generated/lute_std_source.h)

embed_map(
    OUTPUT_HEADER ${GENERATED_HEADER}
    VARIABLE_NAME "LUTE_STD"
    INPUT_FILES ${LUAU_SOURCE_FILES}
    PREFIX "@std/"
)

add_custom_target(luau_std_libs ALL DEPENDS ${GENERATED_HEADER})

add_library(Lute.Std INTERFACE)
add_dependencies(Lute.Std luau_std_libs)
target_include_directories(Lute.Std INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/generated)