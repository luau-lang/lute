load("@prelude//rules.bzl", "cxx_library", "cxx_binary")

def _get_optimization_flags():
    return select({
        "settings//compiler:msvc": select({
            "DEFAULT": ["/O2"],
        }),
        "settings//compiler:clang": select({
            "DEFAULT": ["-O2"],
        }),
    })

def _get_debug_info_flags():
    return select({
        "settings//compiler:msvc": ["/Z7"],
        "settings//compiler:clang": ["-g"],
    })

def _get_linker_config_flags():
    return select({
        "DEFAULT": [],
        "settings//compiler:msvc": ["/DEBUG:FULL", "/INCREMENTAL:NO"],
        "settings//compiler:clang": ["-g", "-O0"],
    })

def default_compiler_flags():
    return                                  \
        _get_optimization_flags() +         \
        _get_debug_info_flags()

def lute_cxx_library(
    name:str,
    visibility=["PUBLIC"],
    srcs=[],
    target_compatible_with=[],
    cxx_toolchain="toolchains//:cxx",
    compiler_flags=[],
    exported_compiler_flags=[],
    exported_linker_flags=[],
    deps=[],
    exported_deps=[],
    frameworks=[],
    link_whole=False
):
    compiler_flags += default_compiler_flags()

    cxx_library(
        name=name,
        link_style="static",
        visibility=visibility,
        _cxx_toolchain=cxx_toolchain,
        target_compatible_with=target_compatible_with,
        srcs=srcs,
        preprocessor_flags=compiler_flags,
        exported_preprocessor_flags=exported_compiler_flags,
        exported_linker_flags=exported_linker_flags,
        deps=deps,
        exported_deps=exported_deps,
        frameworks=frameworks,
        link_whole=link_whole
    )


def lute_cxx_binary(
    name:str,
    srcs,
    target_compatible_with=[],
    cxx_toolchain="toolchains//:cxx",
    headers=[],
    include_directories=[],
    compiler_flags=[],
    exported_compiler_flags=[],
    frameworks=[],
    linker_flags=[],
    deps=[],
):
    compiler_flags += default_compiler_flags()

    linker_flags += _get_linker_config_flags()

    cxx_binary(
        name=name,
        visibility=["PUBLIC"],
        link_style="static",
        _cxx_toolchain=cxx_toolchain,
        target_compatible_with=target_compatible_with,
        srcs=srcs,
        headers=headers,
        include_directories=include_directories,
        preprocessor_flags=compiler_flags,
        frameworks=frameworks,
        linker_flags=linker_flags,
        deps=deps
    )
