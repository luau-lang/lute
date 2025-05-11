function(embed_map)
    # Parse arguments
    set(options)
    set(one_value_args OUTPUT_HEADER VARIABLE_NAME NAMESPACE PREFIX)
    set(multi_value_args INPUT_FILES)
    cmake_parse_arguments(EMBED "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    # Validation
    if(NOT DEFINED EMBED_OUTPUT_HEADER)
        message(FATAL_ERROR "OUTPUT_HEADER must be specified")
    endif()

    if(NOT DEFINED EMBED_PREFIX)
        message(FATAL_ERROR "PREFIX must be specified")
    endif()

    if(NOT DEFINED EMBED_INPUT_FILES)
        message(FATAL_ERROR "INPUT_FILES must be specified")
    endif()

    if(NOT DEFINED EMBED_VARIABLE_NAME)
        message(FATAL_ERROR "VARIABLE_NAME must be specified")
    endif()

    # Ensure constant name is in LOUD_SNAKE_CASE
    string(TOUPPER "${EMBED_VARIABLE_NAME}" const_name)

    # Get a unique name for the generator script
    get_filename_component(target_name "${EMBED_OUTPUT_HEADER}" NAME_WE)
    set(generator_script "${CMAKE_CURRENT_BINARY_DIR}/generate_${target_name}_map.cmake")

    # Ensure the output directory exists
    get_filename_component(output_dir "${EMBED_OUTPUT_HEADER}" DIRECTORY)
    file(WRITE "${generator_script}" "file(MAKE_DIRECTORY \"${output_dir}\")

file(WRITE \"${EMBED_OUTPUT_HEADER}\" \"#ifndef ${const_name}_MAP_H\\n\")
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#define ${const_name}_MAP_H\\n\\n\")
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#include <string_view>\\n\")
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#include <map>\\n\\n\")
")

    # Add namespace if specified
    if(DEFINED EMBED_NAMESPACE)
        file(APPEND "${generator_script}" "
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"namespace ${EMBED_NAMESPACE} {\\n\\n\")
")
    endif()

    # Start map declaration
    file(APPEND "${generator_script}" "
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"const std::map<std::string_view, std::string_view> ${const_name} = {\\n\")
")

    # Process each input file
    foreach(input_file ${EMBED_INPUT_FILES})
        get_filename_component(abs_file ${input_file} ABSOLUTE)
        get_filename_component(file_name ${input_file} NAME)
        file(APPEND "${generator_script}" "
file(READ \"${abs_file}\" file_content)

string(REPLACE \"\\\\\" \"\\\\\\\\\" file_content \"\${file_content}\")
string(REPLACE \"\\\"\" \"\\\\\\\"\" file_content \"\${file_content}\")
string(REPLACE \"\\n\" \"\\\\n\" file_content \"\${file_content}\")
string(REPLACE \"\\r\" \"\\\\r\" file_content \"\${file_content}\")

file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"    {\\\"${EMBED_PREFIX}${file_name}\\\", \\\"\${file_content}\\\"},\\n\")
")
    endforeach()

    # Close map declaration
    file(APPEND "${generator_script}" "
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"};\\n\\n\")
")

    # Close namespace if specified
    if(DEFINED EMBED_NAMESPACE)
        file(APPEND "${generator_script}" "
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"}  // namespace ${EMBED_NAMESPACE}\\n\\n\")
")
    endif()

    # Close header guard
    file(APPEND "${generator_script}" "
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#endif  // ${const_name}_MAP_H\\n\")
")

    # Create a custom command that runs the generator script
    add_custom_command(
        OUTPUT "${EMBED_OUTPUT_HEADER}"
        COMMAND ${CMAKE_COMMAND} -P "${generator_script}"
        DEPENDS ${EMBED_INPUT_FILES} "${generator_script}"
        COMMENT "Generating ${EMBED_OUTPUT_HEADER} with embedded file map"
        VERBATIM
    )
endfunction()
