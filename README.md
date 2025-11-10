# Lute [![CI](https://github.com/luau-lang/lute/actions/workflows/ci.yml/badge.svg)](https://github.com/luau-lang/lute/actions/workflows/ci.yml)

Lute is a standalone runtime for general-purpose programming in [Luau](https://luau.org), and a collection of optional extension libraries for Luau embedders to include to expand the capabilities of the Luau scripts in their software.
It is designed to make it readily feasible to use Luau to write any sort of general-purpose programs, including manipulating files, making network requests, opening sockets, and even making tooling that directly manipulates Luau scripts.
Lute also features a standard library of Luau code, called `std`, that aims to expose a more featureful standard library for general-purpose programming that we hope can be an interface shared across Luau runtimes.

Lute is still very much a work-in-progress, and should be treated as pre-1.0 software without stability guarantees for its API.
We would love to hear from you about your experiences working with other Luau or Lua runtimes, and about what sort of functionality is needed to best make Luau accessible and productive for general-purpose programming.

### Lute Libraries

The Lute repository fundamentally contains three sets of libraries. These are as follows:

- `lute`: The core runtime libraries in C++, which provides the basic functionality for general-purpose Luau programming.
- `std`: The standard library, which extends those core C++ libraries with additional functionality in Luau.
- `batteries`: A collection of useful, standalone Luau libraries that do not depend on `lute`.

Contributions to any of these libraries are welcome, and we encourage you to open issues or pull requests if you have any feedback or contributions to make.

## Building Lute

Lute has a fairly conventional C++ build system built atop CMake. However, in the interest of dogfooding Lute itself, and avoiding the trap of shipping elaborate, difficult-to-maintain CMake configurations that attempt to perform dependency resolution and code generation, we've written a build tool called `luthier` (located at `./tools/luthier.luau`).
`luthier` is written to appropriately run or re-run any of the steps in the build process as needed based on local changes, which affords a more pleasant developer experience for folks working on `lute` than invoking each step manually. Some
`luthier` subcommands like `configure` and `build` just wrap the standard CMake configuration and ninja invocations. Other commands include `fetch` which implements the logic to parse dependency information from the TOML files (named `extern/\*.tune`) and resolve them efficiently using `git`, and `generate` which performs the code generation steps necessary to embed both Lute's CLI frontend commands and Lute's standard library into the executable.
The `generate` step in particular is necessary to producing a full `lute` executable, but we provide empty versions of both embeddings (in `./tools/templates`) to be used for any builds that do _not_ embed the standard library. Since you'll need `lute` to execute `luthier` and you'll need `luthier` to run the code generation step in particular, there are a few different paths to building Lute.

### Building Lute with `lute` installed

The most straightforward, and generally recommended, way to build a local version of `lute` is to have already installed an existing version of `lute`. Today, you can do that using a toolchain manager like [`foreman`](https://github.com/Roblox/foreman), [`rokit`](https://github.com/rojo-rbx/rokit), and [mise-en-place](https://mise.jdx.dev/), or by manually installing a prebuilt binary from our [Releases](https://github.com/luau-lang/lute/releases). With a copy of `lute` present on your system, you can then run the following to perform a clean build:

```bash
# with `lute` on your path...
lute tools/luthier.luau build --clean {lute | Lute.CLI | Lute.Test}
# or referring directly to a specific location...
/path/to/lute tools/luthier.luau build --clean {lute | Lute.CLI | Lute.Test}
# you can also use `run`, instead of `build`, to also invoke the appropriate executable afterwards!
```

### Building Lute from scratch

If you wish to build `lute` from scratch without a version of `lute` already present on your machine, this is still possible! We've provided a small, easily auditable shell script `./tools/bootstrap.sh` that will perform the entire build process in sequence for a totally fresh build. This entails first building a debug version of `lute` called `lute0` without any of the CLI commands implemented in Luau, and without the standard library embedded into the executable. We can then use `lute0` to run `luthier`, perform the requisite code generation step, and then build a fresh release version of `lute`. The script supports a single command-line option `--install` which can be used to install this release executable to a desired location on your machine. By default, this is `$HOME/.lute/bin/lute`, but the script will provide a prompt during its execution about where `lute` should be placed. In order to then use this `lute` executable, please ensure that it is accessible on your `$PATH`.

### Manually building Lute

If you wish to work very manually with the build system, you can, of course, still invoke `cmake` and `ninja` directly after pulling external dependencies into `extern` by hand. In order for the build to succeed, you'll have to provide _some_ version of a handful of generated files, but we provide empty versions to use in `./tools/templates`. A manual build therefore would look something like:

- Copy all of the templates from `./tools/templates` into the right locations to support building a version with no embedded Luau functionality, e.g.
  ```bash
  mkdir -p ./lute/std/src/generated
  cp ./tools/templates/std_impl.cpp ./lute/std/src/generated/modules.cpp
  cp ./tools/templates/std_header.h ./lute/std/src/generated/modules.h
  mkdir -p ./lute/cli/generated
  cp ./tools/templates/cli_impl.cpp ./lute/cli/generated/commands.cpp
  cp ./tools/templates/cli_header.h ./lute/cli/generated/commands.h
  ```
- Configure with `cmake -G=Ninja -B build  -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=1`
- Build a `lute` executable with `ninja -C build lute/cli/lute` or our test suite with `ninja -C build tests/lute-tests`.
- Optionally, use this version to run `luthier generate` to generate the files for embedded Luau functionality.
