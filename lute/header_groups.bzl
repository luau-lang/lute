load("@prelude//rules.bzl", "cxx_library")

def make_header_map(
    headers,
):
    return { x: x for x in headers }

def lute_header_group(
    name: str,
    header_map,
    visibility: list[str] = [],
    exported_deps = [],
    exported_compiler_flags = [],
    target_compatible_with = [],
    header_namespace = "."
):
    cxx_library(
        name = name,
        visibility = visibility,
        target_compatible_with = target_compatible_with,
        exported_headers = header_map,
        exported_deps = exported_deps,
        header_namespace = header_namespace,
        exported_preprocessor_flags = exported_compiler_flags,
    )
