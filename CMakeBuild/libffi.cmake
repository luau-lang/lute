# libffi - Copyright (c) 1996-2025  Anthony Green, Red Hat, Inc and others.
# See source files for details.

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# ``Software''), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED ``AS IS'', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# CMake support adapted from https://github.com/am11/libffi/blob/feature/cmake-build-configs/CMakeLists.txt
# Modified so everything is done in a single file, properly builds with MSVC and some other fixes.

cmake_minimum_required(VERSION 3.10)
project(libffi C ASM)

set(LIBFFI_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/extern/libffi)

set(SOURCES_LIST
    ${LIBFFI_SOURCE_DIR}/src/closures.c
    ${LIBFFI_SOURCE_DIR}/src/java_raw_api.c
    ${LIBFFI_SOURCE_DIR}/src/prep_cif.c
    ${LIBFFI_SOURCE_DIR}/src/raw_api.c
    ${LIBFFI_SOURCE_DIR}/src/types.c
    ${LIBFFI_SOURCE_DIR}/src/tramp.c
    )

if(CMAKE_BUILD_TYPE MATCHES Debug)
    list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/debug.c)
    add_definitions(-DFFI_DEBUG)
endif()

# configure platform
if("${CMAKE_C_COMPILER_ARCHITECTURE_ID}" STREQUAL "")
    set(HOST_ARCH ${CMAKE_SYSTEM_PROCESSOR})
else()
    set(HOST_ARCH ${CMAKE_C_COMPILER_ARCHITECTURE_ID})
endif()


if("${TARGET_PLATFORM}" STREQUAL "")
    if(HOST_ARCH MATCHES x64|x86_64|AMD64|amd64)
        if(CMAKE_SYSTEM_NAME STREQUAL Windows)
            set(TARGET_PLATFORM X86_WIN64)
        else()
            set(TARGET_PLATFORM X86_64)
        endif()
    elseif(HOST_ARCH MATCHES i.*86.*|X86|x86)
        if(CMAKE_SYSTEM_NAME MATCHES Windows)
            set(TARGET_PLATFORM X86_WIN32)
        else()
            set(TARGET_PLATFORM X86)
        endif()

        if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
            set(TARGET_PLATFORM X86_DARWIN)
        elseif(CMAKE_SYSTEM_NAME MATCHES FreeBSD|OpenBSD)
            set(TARGET_PLATFORM X86_FREEBSD)
        endif()
    elseif(HOST_ARCH MATCHES aarch64|ARM64|arm64)
        if(CMAKE_SYSTEM_NAME MATCHES Windows)
            set(TARGET_PLATFORM ARM_WIN64)
        else()
            set(TARGET_PLATFORM AARCH64)
        endif()
    elseif(HOST_ARCH MATCHES arm.*|ARM.*)
        if(CMAKE_SYSTEM_NAME MATCHES Windows)
            set(TARGET_PLATFORM ARM_WIN32)
        else()
            set(TARGET_PLATFORM ARM)
        endif()
    else()
        message(FATAL_ERROR "Unknown host.")
    endif()
endif()

message(STATUS "Building for TARGET_PLATFORM: ${TARGET_PLATFORM}  TARGETDIR: ${TARGETDIR}")

# configure options
include(CheckCSourceCompiles)
include(CheckCSourceRuns)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckIncludeFiles)
include(CheckSymbolExists)
include(CheckTypeSize)
include(TestBigEndian)

# options in AC counterpart can be overriden from command-line
# e.g.:  cmake .. -DFFI_MMAP_EXEC_EMUTRAMP_PAX=1 -DVERSION=X.Y
if(NOT DEFINED VERSION)
    set(VERSION 3.x-dev)
endif()
set(PACKAGE libffi)
set(PACKAGE_BUGREPORT http://github.com/libffi/libffi/issues)
set(PACKAGE_NAME ${PACKAGE})
set(PACKAGE_STRING "${PACKAGE} ${VERSION}")
set(PACKAGE_TARNAME ${PACKAGE})
set(PACKAGE_URL http://github.com/libffi/libffi)
set(PACKAGE_VERSION ${VERSION})
set(TARGET ${TARGET_PLATFORM})
set(LT_OBJDIR .libs/)

check_type_size (size_t SIZEOF_SIZE_T)

if(SIZEOF_SIZE_T STREQUAL "")
    set(size_t "unsinged int")
endif()

if(MSVC)
    get_filename_component(COMPILER_DIR "${CMAKE_C_COMPILER}" DIRECTORY)
else()
    enable_language(ASM)
endif()

set(FFI_EXEC_TRAMPOLINE_TABLE 0)
if(TARGET_PLATFORM STREQUAL X86_WIN64)
    if(MSVC)
        list(APPEND WIN_ASSEMBLY_LIST src/x86/win64_intel.S)
        enable_language(ASM_MASM)
    else()
        list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/x86/win64.S)
    endif()
    list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/x86/ffiw64.c)

    set(TARGETDIR x86)
elseif(TARGET_PLATFORM STREQUAL X86_64)
    list(APPEND SOURCES_LIST
        ${LIBFFI_SOURCE_DIR}/src/x86/ffi64.c
        ${LIBFFI_SOURCE_DIR}/src/x86/unix64.S)

    if(SIZEOF_SIZE_T EQUAL 4 AND TARGET_PLATFORM MATCHES X86.*)
        set(CMAKE_REQUIRED_FLAGS "-Werror")

        check_c_source_compiles(
            "
            int main(void)
            {
                return __x86_64__;
            }
            "
            TARGET_X32)

        set(CMAKE_REQUIRED_FLAGS)
    endif()

    if(NOT TARGET_X32)
        list(APPEND SOURCES_LIST
        ${LIBFFI_SOURCE_DIR}/src/x86/ffiw64.c
        ${LIBFFI_SOURCE_DIR}/src/x86/win64.S)
    endif()

    set(TARGETDIR x86)
elseif(TARGET_PLATFORM MATCHES X86.*)
    if(MSVC)
        list(APPEND WIN_ASSEMBLY_LIST src/x86/sysv_intel.S)
        set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")
        enable_language(ASM_MASM) 
    else()
        list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/x86/sysv.S)
    endif()

    list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/x86/ffi.c)
    set(TARGETDIR x86)
elseif(TARGET_PLATFORM MATCHES ARM_WIN64|AARCH64)
    if(TARGET_PLATFORM STREQUAL ARM_WIN64)
        set(CMAKE_ASM_MASM_COMPILER ${COMPILER_DIR}/armasm64.exe)
        set(CMAKE_ASM_COMPILER ${CMAKE_ASM_MASM_COMPILER})
        list(APPEND WIN_ASSEMBLY_LIST src/aarch64/win64_armasm.S)
        file(COPY ${LIBFFI_SOURCE_DIR}/src/aarch64/ffitarget.h DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/include)
        enable_language(ASM)
    else()
        list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/aarch64/sysv.S)
    endif()

    list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/aarch64/ffi.c)
    set(TARGETDIR aarch64)
elseif(TARGET_PLATFORM MATCHES ARM.*)
    if(MSVC)
        set(CMAKE_ASM_MASM_COMPILER ${COMPILER_DIR}/armasm.exe)
        set(CMAKE_ASM_COMPILER ${CMAKE_ASM_MASM_COMPILER})
        list(APPEND WIN_ASSEMBLY_LIST src/arm/sysv_msvc_arm32.S)
        file(COPY ${LIBFFI_SOURCE_DIR}/src/arm/ffitarget.h DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/include)
        enable_language(ASM)
    else()
        list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/arm/sysv.S)
    endif()

    list(APPEND SOURCES_LIST ${LIBFFI_SOURCE_DIR}/src/arm/ffi.c)
    set(TARGETDIR arm)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL Darwin AND TARGET_PLATFORM STREQUAL AARCH64)
    set(FFI_EXEC_TRAMPOLINE_TABLE 1)
elseif(CMAKE_SYSTEM_NAME STREQUAL Darwin OR TARGET_PLATFORM MATCHES .*FREEBSD.*)
    set(FFI_MMAP_EXEC_WRIT 1)
endif()

check_type_size (double SIZEOF_DOUBLE)
check_type_size ("long double" SIZEOF_LONG_DOUBLE)

if(SIZEOF_LONG_DOUBLE STREQUAL "")
    set(HAVE_LONG_DOUBLE 0)

    if(DEFINED HAVE_LONG_DOUBLE_VARIANT)
        set(HAVE_LONG_DOUBLE 1)
    elseif(NOT SIZEOF_DOUBLE EQUAL SIZEOF_LONG_DOUBLE)
        set(HAVE_LONG_DOUBLE 1)
    endif()
else()
    set(HAVE_LONG_DOUBLE 1)
endif()

check_function_exists(alloca C_ALLOCA)
check_function_exists (mmap HAVE_MMAP)

check_symbol_exists (MAP_ANON sys/mman.h HAVE_MMAP_ANON)

set(HAVE_MMAP_DEV_ZERO OFF)

check_include_file(alloca.h HAVE_ALLOCA_H)

check_c_source_compiles(
    "
    #include <alloca.h>
    int main()
    {
        char* x = alloca(1024);
        return 0;
    }
    "
    HAVE_ALLOCA)

check_include_file(dlfcn.h HAVE_DLFCN_H)
check_include_file(inttypes.h HAVE_INTTYPES_H)
check_include_file(memory.h HAVE_MEMORY_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stdlib.h HAVE_STDLIB_H)
check_include_file(strings.h HAVE_STRINGS_H)
check_include_file(string.h HAVE_STRING_H)
check_include_file(sys/mman.h HAVE_SYS_MMAN_H)
check_include_file(sys/stat.h HAVE_SYS_STAT_H)
check_include_file(sys/types.h HAVE_SYS_TYPES_H)
check_include_file(unistd.h HAVE_UNISTD_H)
check_include_files("stdlib.h;stdarg.h;string.h;float.h" STDC_HEADERS)

check_symbol_exists(memcpy string.h HAVE_MEMCPY)
set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")
check_symbol_exists(mkostemp stdlib.h HAVE_MKOSTEMP)
set(CMAKE_REQUIRED_DEFINITIONS)

if (NOT MSVC)
    find_program(OBJDUMP objdump)
    find_program(NM NAMES nm llvm-nm)

    if(OBJDUMP)
        set(DUMPTOOL_CMD "objdump -t -h") # on macOS -t -h can't be combined
        set(EH_FRAME_GREP_EXPR "grep -A1 -n eh_frame | grep -q READONLY")
    elseif(NM)
        set(DUMPTOOL_CMD "nm -a")
        set(EH_FRAME_GREP_EXPR "grep -q ' r \.eh_frame'")
    endif()

    execute_process(
        COMMAND
            sh -c "echo 'extern void foo (void); void bar (void) { foo (); foo (); }' | ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} -xc -c -fpic -fexceptions -o conftest.o - 2>&1;
                   ${DUMPTOOL_CMD} conftest.o 2>&1 | ${EH_FRAME_GREP_EXPR}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_VARIABLE IGNORE
        ERROR_VARIABLE IGNORE
        RESULT_VARIABLE HAVE_RO_EH_FRAME_EXITCODE)

    file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/conftest.*)

    if(HAVE_RO_EH_FRAME_EXITCODE EQUAL "0")
        set(HAVE_RO_EH_FRAME 1)
        set(EH_FRAME_FLAGS "a")
        message(STATUS "Checking if .eh_frame section is read-only - yes")
    else()
        set(EH_FRAME_FLAGS "aw")
        message(STATUS "Checking if .eh_frame section is read-only - no")
    endif()

    execute_process(
        COMMAND sh -c "echo '.text; foo: nop; .data; .long foo-.; .text' | ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} -xassembler -c -o conftest.o - 2>&1"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_VARIABLE IGNORE
        ERROR_VARIABLE IGNORE
        RESULT_VARIABLE HAVE_AS_X86_PCREL_EXITCODE)

    file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/conftest.*)

    if(HAVE_AS_X86_PCREL_EXITCODE EQUAL "0")
        set(HAVE_AS_X86_PCREL 1)
        message(STATUS "Checking HAVE_AS_X86_PCREL - yes")
    else()
        message(STATUS "Checking HAVE_AS_X86_PCREL - no")
    endif()

    execute_process(
        COMMAND
            sh -c "echo '.text;.globl foo;foo:;jmp bar;.section .eh_frame,\"a\",@unwind;bar:' | ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} -xassembler -Wa,--fatal-warnings -c -o conftest.o - 2>&1 &&
                   echo 'extern void foo();int main(){foo();}' | ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} conftest.o -xc - 2>&1"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_VARIABLE IGNORE
        ERROR_VARIABLE IGNORE
        RESULT_VARIABLE HAVE_AS_X86_64_UNWIND_SECTION_TYPE_EXITCODE)

    file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/conftest.*)

    if(HAVE_AS_X86_64_UNWIND_SECTION_TYPE_EXITCODE EQUAL "0")
        set(HAVE_AS_X86_64_UNWIND_SECTION_TYPE 1)
        message(STATUS "Checking HAVE_AS_X86_64_UNWIND_SECTION_TYPE - yes")
    else()
        message(STATUS "Checking HAVE_AS_X86_64_UNWIND_SECTION_TYPE - no")
    endif()

    execute_process(
        COMMAND sh -c "echo 'int __attribute__ ((visibility (\"hidden\"))) foo(void){return 1;}' | ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} -xc -Werror -S -o- - 2>&1 |
                       grep -q '\\.hidden.*foo'"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_VARIABLE IGNORE
        ERROR_VARIABLE IGNORE
        RESULT_VARIABLE HAVE_HIDDEN_VISIBILITY_ATTRIBUTE_EXITCODE)

    if(HAVE_HIDDEN_VISIBILITY_ATTRIBUTE_EXITCODE EQUAL "0")
        set(HAVE_HIDDEN_VISIBILITY_ATTRIBUTE 1)
        message(STATUS "Checking HAVE_HIDDEN_VISIBILITY_ATTRIBUTE - yes")
    else()
        message(STATUS "Checking HAVE_HIDDEN_VISIBILITY_ATTRIBUTE - no")
    endif()
endif()

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/conftest.c "void nm_test_func(){} int main(){nm_test_func();return 0;}")

if(MSVC)
    execute_process(
        COMMAND "${CMAKE_C_COMPILER}" ${CMAKE_C_FLAGS} /c conftest.c
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_VARIABLE IGNORE
        ERROR_VARIABLE IGNORE
        RESULT_VARIABLE SYMBOL_UNDERSCORE_EXITCODE)

    if(SYMBOL_UNDERSCORE_EXITCODE EQUAL "0")
        execute_process(
            COMMAND "${COMPILER_DIR}/dumpbin.exe" /ALL /RAWDATA:NONE conftest.obj | findstr _nm_test_func > NUL
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            OUTPUT_VARIABLE IGNORE
            ERROR_VARIABLE IGNORE
            RESULT_VARIABLE SYMBOL_UNDERSCORE_EXITCODE)
    endif()
elseif()
    execute_process(
        COMMAND sh -c "${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} -xc -c -o conftest.o conftest.c 2>&1;
                       ${DUMPTOOL_CMD} conftest.o 2>&1 | grep -q _nm_test_func"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_VARIABLE IGNORE
        ERROR_VARIABLE IGNORE
        RESULT_VARIABLE SYMBOL_UNDERSCORE_EXITCODE)
endif()

file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/conftest.*)

if(SYMBOL_UNDERSCORE_EXITCODE EQUAL "0")
    set(SYMBOL_UNDERSCORE 1)
    message(STATUS "Checking if symbols are underscored - yes")
else()
    message(STATUS "Checking if symbols are underscored - no")
endif()

check_c_source_compiles(
    "
    asm (\".cfi_sections\\\\n\\\\t.cfi_startproc\\\\n\\\\t.cfi_endproc\");
    int main(void)
    {
        return 0;
    }
    "
    HAVE_AS_CFI_PSEUDO_OP)

foreach(ASM_PATH IN LISTS WIN_ASSEMBLY_LIST)
    get_filename_component(ASM_FILENAME "${ASM_PATH}" NAME_WE)
    get_filename_component(ASM_DIRNAME "${ASM_PATH}" DIRECTORY)

    add_custom_command(
        COMMAND "${CMAKE_C_COMPILER}" /nologo /P /EP /I. /I"${LIBFFI_SOURCE_DIR}/${ASM_DIRNAME}" /Fi"${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm" /Iinclude
                /I"${LIBFFI_SOURCE_DIR}/include" "${LIBFFI_SOURCE_DIR}/${ASM_PATH}"
        DEPENDS ${LIBFFI_SOURCE_DIR}/${ASM_PATH}
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm
        COMMENT "Preprocessing ${LIBFFI_SOURCE_DIR}/${ASM_PATH}. Outputting to ${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm")

    set_source_files_properties("${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm" PROPERTIES GENERATED TRUE)

    if(TARGET_PLATFORM MATCHES X86.*)
        list(APPEND SOURCES_LIST ${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm)
    else()
        add_custom_command(
            COMMAND "${CMAKE_ASM_MASM_COMPILER}" /Fo "${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.obj" "${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm"
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.obj
            COMMENT "Assembling ${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.asm")

        set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.obj PROPERTIES EXTERNAL_OBJECT TRUE)

        list(APPEND OBJECTS_LIST ${CMAKE_CURRENT_BINARY_DIR}/${ASM_FILENAME}.obj)
    endif()
endforeach()

file(COPY ${FFI_CONFIG_FILE} DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
file(COPY ${LIBFFI_SOURCE_DIR}/src/${TARGETDIR}/ffitarget.h DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/include)

include_directories(${LIBFFI_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include)
 
add_definitions(-DFFI_BUILDING)
add_definitions(-DFFI_STATIC_BUILD)

add_library(libffi_obj OBJECT ${SOURCES_LIST})
set_property(TARGET libffi_obj PROPERTY POSITION_INDEPENDENT_CODE 1)

add_library(libffi STATIC $<TARGET_OBJECTS:libffi_obj>)

target_include_directories(libffi PUBLIC
    ${CMAKE_CURRENT_BINARY_DIR}/include
)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

# generate ffi.h
set(FFI_VERSION_STRING "3.5.2")
set(FFI_VERSION_NUMBER 30502)

configure_file(${LIBFFI_SOURCE_DIR}/include/ffi.h.in ${CMAKE_CURRENT_BINARY_DIR}/include/ffi.h)

# generate fficonfig.h
set(FFI_NO_RAW_API 0)
set(FFI_NO_STRUCTS 0)

if(APPLE AND CMAKE_OSX_ARCHITECTURES)
    list(LENGTH CMAKE_OSX_ARCHITECTURES arch_count)
    if(arch_count GREATER 1)
        set(AC_APPLE_UNIVERSAL_BUILD 1)
    endif()
endif()

configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/CMakeBuild/libffi.fficonfig.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/include/fficonfig.h
)
