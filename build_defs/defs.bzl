load("@prelude//rules.bzl", "cxx_binary", "cxx_library", "genrule")

_LUTE_CXX_FLAGS = [
    "-std=c++17",
    "-Wall",
    "-Werror",
    "-ffunction-sections",
    "-fdata-sections",
    "-fvisibility=hidden",
] + (["-mmacosx-version-min=12.0"] if host_info().os.is_macos else [])

_LUTE_LINK_FLAGS = [
    "-dead_strip",
    "-mmacosx-version-min=12.0",
    "-framework", "CoreFoundation",
    "-framework", "CoreServices",
    "-framework", "SystemConfiguration",
    "-framework", "Security",
    "-framework", "IOKit",
] if host_info().os.is_macos else [
    "-Wl,--gc-sections",
    "-lpthread",
    "-ldl",
    "-lm",
]

_DEFAULT_PLATFORM = "//platforms:default"

def lute_cxx_library(
        name,
        srcs = [],
        headers = [],
        exported_headers = [],
        deps = [],
        exported_deps = [],
        compiler_flags = [],
        preprocessor_flags = [],
        exported_preprocessor_flags = [],
        header_namespace = "",
        preferred_linkage = "static",
        visibility = ["PUBLIC"],
        **kwargs):
    cxx_library(
        name = name,
        srcs = srcs,
        headers = headers,
        exported_headers = exported_headers,
        deps = deps,
        exported_deps = exported_deps,
        compiler_flags = _LUTE_CXX_FLAGS + compiler_flags,
        preprocessor_flags = preprocessor_flags,
        exported_preprocessor_flags = exported_preprocessor_flags,
        header_namespace = header_namespace,
        preferred_linkage = preferred_linkage,
        default_target_platform = _DEFAULT_PLATFORM,
        visibility = visibility,
        **kwargs,
    )

def lute_cxx_binary(
        name,
        srcs = [],
        headers = [],
        deps = [],
        compiler_flags = [],
        preprocessor_flags = [],
        link_style = "static",
        visibility = ["PUBLIC"],
        **kwargs):
    cxx_binary(
        name = name,
        srcs = srcs,
        headers = headers,
        header_namespace = "",
        deps = deps,
        compiler_flags = _LUTE_CXX_FLAGS + compiler_flags,
        preprocessor_flags = preprocessor_flags,
        linker_flags = _LUTE_LINK_FLAGS,
        link_style = link_style,
        default_target_platform = _DEFAULT_PLATFORM,
        visibility = visibility,
        **kwargs,
    )

def lute_genrule(
        name,
        cmd,
        srcs = [],
        out = None,
        visibility = ["PUBLIC"],
        **kwargs):
    genrule(
        name = name,
        cmd = cmd,
        srcs = srcs,
        out = out,
        default_target_platform = _DEFAULT_PLATFORM,
        visibility = visibility,
        **kwargs,
    )
