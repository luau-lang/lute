function(embed_files)
    set(options)
    set(one_value_args OUTPUT_HEADER VARIABLE_NAME ROOT_DIR KEEP_EXTENSION PATH_PREFIX GLOB_DIRS)
    set(multi_value_args INPUT_FILES)
    cmake_parse_arguments(EMBED "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    if(NOT DEFINED EMBED_OUTPUT_HEADER)
        message(FATAL_ERROR "OUTPUT_HEADER must be specified")
    endif()
    if(NOT DEFINED EMBED_INPUT_FILES)
        message(FATAL_ERROR "INPUT_FILES must be specified")
    endif()
    if(NOT DEFINED EMBED_VARIABLE_NAME)
        message(FATAL_ERROR "VARIABLE_NAME must be specified")
    endif()

    if(NOT DEFINED EMBED_ROOT_DIR)
        set(EMBED_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    if(NOT DEFINED EMBED_KEEP_EXTENSION)
        set(EMBED_KEEP_EXTENSION ON)
    endif()
    if(NOT DEFINED EMBED_GLOB_DIRS)
        set(EMBED_GLOB_DIRS ON)
    endif()

    if (NOT DEFINED EMBED_PATH_PREFIX)
        set(EMBED_PATH_PREFIX "")
    endif()

    string(TOUPPER "${EMBED_VARIABLE_NAME}" const_name)

    # We need to build a flat list of absolute files and their relative keys
    set(ABS_INPUTS)
    set(REL_KEYS)
    foreach(item IN LISTS EMBED_INPUT_FILES)
        get_filename_component(abs_item "${item}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        if(IS_DIRECTORY "${abs_item}")
            if(EMBED_GLOB_DIRS)
                file(GLOB_RECURSE found_files
                    RELATIVE "${EMBED_ROOT_DIR}"
                    "${abs_item}/*")
                foreach(f IN LISTS found_files)
                    # We need to compute absolute path and normalized relative key here
                    set(abs_f "${EMBED_ROOT_DIR}/${f}")
                    if(NOT IS_DIRECTORY "${abs_f}")
                        # Normalize slashes
                        string(REPLACE "\\" "/" rel_norm "${f}")
                        if(NOT EMBED_KEEP_EXTENSION)
                            get_filename_component(nwe "${rel_norm}" NAME_WE)
                            get_filename_component(dirp "${rel_norm}" DIRECTORY)
                            if(dirp STREQUAL "")
                                set(rel_norm "${nwe}")
                            else()
                                set(rel_norm "${dirp}/${nwe}")
                            endif()
                        endif()
                        list(APPEND ABS_INPUTS "${abs_f}")
                        list(APPEND REL_KEYS "${rel_norm}")
                    endif()
                endforeach()
            else()
                message(FATAL_ERROR "Directory '${item}' given but GLOB_DIRS is OFF")
            endif()
        else()
            # Handle single file relative key sfrom ROOT_DIR
            file(RELATIVE_PATH rel "${EMBED_ROOT_DIR}" "${abs_item}")
            if(rel STREQUAL "" OR rel MATCHES "^\\.\\.")
                # If outside ROOT_DIR, fall back to name only
                get_filename_component(rel "${abs_item}" NAME)
            endif()
            string(REPLACE "\\" "/" rel_norm "${rel}")
            if(NOT EMBED_KEEP_EXTENSION)
                get_filename_component(nwe "${rel_norm}" NAME_WE)
                get_filename_component(dirp "${rel_norm}" DIRECTORY)
                if(dirp STREQUAL "")
                    set(rel_norm "${nwe}")
                else()
                    set(rel_norm "${dirp}/${nwe}")
                endif()
            endif()
            list(APPEND ABS_INPUTS "${abs_item}")
            list(APPEND REL_KEYS "${rel_norm}")
        endif()
    endforeach()

    if(ABS_INPUTS STREQUAL "")
        message(FATAL_ERROR "No input files resolved under INPUT_FILES")
    endif()

    # create generator script

    get_filename_component(target_name "${EMBED_OUTPUT_HEADER}" NAME_WE)
    set(generator_script "${CMAKE_CURRENT_BINARY_DIR}/generate_${target_name}_map.cmake")
    get_filename_component(output_dir "${EMBED_OUTPUT_HEADER}" DIRECTORY)

    file(WRITE "${generator_script}" "file(MAKE_DIRECTORY \"${output_dir}\")\n")
    file(APPEND "${generator_script}" "file(WRITE \"${EMBED_OUTPUT_HEADER}\" \"#ifndef ${const_name}_MAP_H\\n\")\n")
    file(APPEND "${generator_script}" "file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#define ${const_name}_MAP_H\\n\\n\")\n")
    file(APPEND "${generator_script}" "file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#include <string>\\n\")\n")
    file(APPEND "${generator_script}" "file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#include <map>\\n\\n\")\n")
    file(APPEND "${generator_script}" "file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"static const std::map<std::string, const char*> ${const_name} = {\\n\")\n")

    list(LENGTH ABS_INPUTS _n)
    math(EXPR last_index "${_n} - 1")
    set(idx 0)
    foreach(abs_file rel_key IN ZIP_LISTS ABS_INPUTS REL_KEYS)
        set(has_comma ",")
        if(idx EQUAL last_index)
            set(has_comma "")
        endif()

        file(APPEND "${generator_script}" "
file(READ \"${abs_file}\" file_content)
string(REPLACE \"\\\\\" \"\\\\\\\\\" file_content \"\${file_content}\")
string(REPLACE \"\\\"\" \"\\\\\\\"\" file_content \"\${file_content}\")
string(REPLACE \"\\n\" \"\\\\n\" file_content \"\${file_content}\")
string(REPLACE \"\\r\" \"\\\\r\" file_content \"\${file_content}\")
file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"    {\\\"${EMBED_PATH_PREFIX}${rel_key}\\\", \\\"\${file_content}\\\"}${has_comma}\\n\")
")
        math(EXPR idx "${idx} + 1")
    endforeach()

    file(APPEND "${generator_script}" "file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"};\\n\\n\")\n")
    file(APPEND "${generator_script}" "file(APPEND \"${EMBED_OUTPUT_HEADER}\" \"#endif // ${const_name}_MAP_H\\n\")\n")

    add_custom_command(
        OUTPUT "${EMBED_OUTPUT_HEADER}"
        COMMAND ${CMAKE_COMMAND} -P "${generator_script}"
        DEPENDS ${ABS_INPUTS} "${generator_script}"
        COMMENT "Generating ${EMBED_OUTPUT_HEADER} with embedded file map"
        VERBATIM
    )
endfunction()
