load("@lute//:cxx.bzl", "lute_cxx_library", "lute_cxx_binary")
load("@lute//:glob.bzl", "subdir_glob")
load("@lute//:header_groups.bzl", "lute_header_group")

lute_header_group(
    name = "lute-fs-headers",
    visibility = [],
    header_map = subdir_glob([
        ("fs/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-fs",
    srcs = glob(["fs/src/*.cpp"]),
    exported_deps = [
        ":lute-fs-headers",
    ]
)

lute_header_group(
    name = "lute-luau-headers",
    visibility = [],
    header_map = subdir_glob([
        ("luau/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-luau",
    srcs = glob(["luau/src/*.cpp"]),
    exported_deps = [
        ":lute-luau-headers",
    ]
)

lute_header_group(
    name = "lute-net-headers",
    visibility = [],
    header_map = subdir_glob([
        ("net/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-net",
    srcs = glob(["net/src/*.cpp"]),
    exported_deps = [
        ":lute-net-headers",
    ]
)

lute_header_group(
    name = "lute-process-headers",
    visibility = [],
    header_map = subdir_glob([
        ("process/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-process",
    srcs = glob(["process/src/*.cpp"]),
    exported_deps = [
        ":lute-process-headers",
    ]
)

lute_header_group(
    name = "lute-runtime-headers",
    visibility = [],
    header_map = subdir_glob([
        ("runtime/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-runtime",
    srcs = glob(["runtime/src/*.cpp"]),
    exported_deps = [
        ":lute-runtime-headers",
    ]
)

lute_header_group(
    name = "lute-std-headers",
    visibility = [],
    header_map = subdir_glob([
        ("std/include", "lute/*.h"),
    ])
)

lute_header_group(
    name = "lute-std-generated-headers",
    visibility = [],
    header_map = subdir_glob([
        ("std/src", "generated/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-std",
    srcs = glob(["std/src/*.cpp", "std/src/generated/*.cpp"]),
    exported_deps = [
        ":lute-std-headers",
        ":lute-std-generated-headers"
    ]
)

lute_header_group(
    name = "lute-system-headers",
    visibility = [],
    header_map = subdir_glob([
        ("system/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-system",
    srcs = glob(["system/src/*.cpp"]),
    exported_deps = [
        ":lute-system-headers",
    ]
)

lute_header_group(
    name = "lute-task-headers",
    visibility = [],
    header_map = subdir_glob([
        ("task/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-task",
    srcs = glob(["task/src/*.cpp"]),
    exported_deps = [
        ":lute-task-headers",
    ]
)

lute_header_group(
    name = "lute-vm-headers",
    visibility = [],
    header_map = subdir_glob([
        ("vm/include", "lute/*.h"),
    ])
)

lute_cxx_library(
    name = "lute-vm",
    srcs = glob(["vm/src/*.cpp"]),
    exported_deps = [
        ":lute-vm-headers",
    ]
)

lute_header_group(
    name = "lute-cli-headers",
    visibility = [],
    header_map = subdir_glob([
        ("cli", "*.h"),
    ])
)

_lute_binary_ldflags = select(
    {
        "config//os:macos": [],
        "config//os:linux": [
            "-lpthread",
        ],
        "config//os:windows": [],
    }
)

lute_cxx_binary(
    name = "lute",
    srcs = glob([
        "cli/src/main.cpp",
        "cli/src/tc.cpp",
    ]),
    linker_flags = _lute_binary_ldflags,
    deps = [
        ":lute-cli-headers",
        ":lute-fs",
        ":lute-luau",
        ":lute-net",
        ":lute-process",
        ":lute-runtime",
        ":lute-system",
        ":lute-task",
        ":lute-vm",
    ] + select({
        "DEFAULT": [],
        "config//os:windows": ["toolchains//windows/winsdk:headers"]
    }),
)
