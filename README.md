# Lute [![CI](https://github.com/luau-lang/lute/actions/workflows/ci.yml/badge.svg)](https://github.com/luau-lang/lute/actions/workflows/ci.yml)

Lute is a standalone runtime for general-purpose programming in [Luau](https://luau.org). It is designed to make it easy
to write any sort of general-purpose programs in Luau, including manipulating files, making network requests, and even
developing tooling that directly manipulates Luau scripts. In addition to the runtime, Lute also includes a standard
library of Luau code, called `std`, that aims to expose a more featureful standard library for general-purpose
programming beyond just the runtime capabilities. We're working within Roblox to make `std` a shared interface across
our Luau runtimes, so that large portions of code written for Lute can be used in Roblox, and vice versa.

### Goals of Lute

In its current state, Lute provides a set of core runtime libraries that have already proven useful to us at Roblox in
building both developer tooling for Luau and internal infrastructure projects. Our 1.0.0 release intended to provide a
stable version that this infrastructure could rely on as we continue to develop Lute and its standard library further.
Neither of these facts are intended to suggest that Lute is a finished product, and we expect to continue to develop it
further in the future.

Our high-level goal with Lute is to build out the requisite tooling and support for Luau to work effectively as
general-purpose programming language, not limited to its current use in Roblox. We hope to continue to develop Lute and
its standard library to provide a more complete experience for general-purpose programming in Luau, and we welcome
contributions from the community to help us achieve this goal. There are still many gaps and areas we'd like to improve,
and we expect it will take plenty of time to get there. We hope that Lute can serve as a useful tool for the community
in the meantime, and again we welcome feedback and contributions to help us improve it.

### Lute Libraries

The Lute repository fundamentally contains three sets of libraries. These are as follows:

- `lute`: The core runtime libraries in C++, which provides the basic functionality for general-purpose Luau
  programming. These libraries extend Luau with additional capabilities for file I/O, networking, and other
  general-purpose programming tasks.
- `std`: The standard library, which extends those core C++ libraries with additional functionality in Luau. These
  libraries are embeddeded in Lute and any Lute-compiled executable, and can be treated as a extension of the runtime.
- `batteries`: A collection of useful, standalone Luau libraries that do not depend on `lute`. These libraries are ones
  that we intend to eventually separate from Lute itself, and publish as independent packages once a good dependency
  management solution is in place.

Contributions to any of these libraries are welcome, and we encourage you to open issues or pull requests if you have
any feedback or contributions to make.

## Building Lute

Lute has a fairly conventional C++ build system built atop CMake. However, in the interest of dogfooding Lute itself,
and avoiding the trap of shipping elaborate, difficult-to-maintain CMake configurations that attempt to perform
dependency resolution and code generation, we've written a build tool called `luthier` (located at
`./tools/luthier.luau`). `luthier` is written to appropriately run or re-run any of the steps in the build process as
needed based on local changes, which affords a more pleasant developer experience for folks working on `lute` than
invoking each step manually. Some `luthier` subcommands like `configure` and `build` just wrap the standard CMake
configuration and ninja invocations. Other commands include `fetch` which implements the logic to parse dependency
information from the TOML files (named `extern/\*.tune`) and resolve them efficiently using `git`, and `generate` which
performs the code generation steps necessary to embed both Lute's CLI frontend commands and Lute's standard library into
the executable. The `generate` step in particular is necessary to producing a full `lute` executable. Since you'll need
`lute` to execute `luthier` and you'll need `luthier` to run the code generation step in particular, there are a few
different paths to building Lute. If you do not have `lute` available to run this step, the CMake option
`-DLUTE_STDLESS=ON` can be passed to skip embedding entirely.

As a result, building a full version of Lute requires a local version of `lute` to run the code generation. We've
provide a few paths below for resolving this bootstrapping problem, depending on your preferences and constraints. You
can also download and manually install a prebuilt binary from our [Releases](https://github.com/luau-lang/lute/releases)
page, and place it wherever you'd like.

### Building Lute from scratch

The simplest way to build `lute` without a version of `lute` already present is by bootstrapping it yourself. Toward
that end, we provide a small, easily auditable shell script `./tools/bootstrap.sh` that will perform the entire build
process in sequence for a totally fresh build. This entails first building a debug version of `lute` called `lute0`
without any of the CLI commands implemented in Luau, and without the standard library embedded into the executable. We
can then use `lute0` to run `luthier`, perform the requisite code generation step, and then build a fresh release
version of `lute`. The script supports a single command-line option `--install` which can be used to install this
release executable to a desired location on your machine. By default, this is `$HOME/.lute/bin/lute`, but the script
will provide a prompt during its execution about where `lute` should be placed. In order to then use this `lute`
executable, please ensure that it is accessible on your `$PATH`.

For subsequent builds, you can use your current copy of `lute` to invoke `luthier` directly to perform clean or
incremental builds of the CLI executable or the test suite:

```bash
# with `lute` on your path...
lute tools/luthier.luau build --clean {lute | Lute.CLI | Lute.Test}
# or referring directly to a specific location...
/path/to/lute tools/luthier.luau build --clean {lute | Lute.CLI | Lute.Test}
# you can also use `run`, instead of `build`, to also invoke the appropriate executable afterwards!
```

### Building Lute with a toolchain manager

A popular approach in the Roblox community generally is to leverage toolchain managers to handle the installation and
setup of developer tooling for projects, and this approach works just as well for building Lute. Out of the box, we
provide configurations for two popular toolchain managers, [`foreman`](https://github.com/Roblox/foreman) and
[`rokit`](https://github.com/rojo-rbx/rokit). You can invoke them with `foreman install` or `rokit install` respectively
to have them download an appropriate version of `lute` to use for the build process. With this copy present on your
system, you can then run the following to perform a clean build:

```bash
# with `lute` on your path...
lute tools/luthier.luau build --clean {lute | Lute.CLI | Lute.Test}
# or referring directly to a specific location...
/path/to/lute tools/luthier.luau build --clean {lute | Lute.CLI | Lute.Test}
# you can also use `run`, instead of `build`, to also invoke the appropriate executable afterwards!
```

### Manually building Lute

If you wish to work very manually with the build system, you can, of course, still invoke `cmake` and `ninja` directly
after pulling external dependencies into `extern` by hand. This will have you performing the steps of the bootstrap
script yourself. A manual build therefore would look something like:

- Fetch all the external dependencies from `extern` by hand, consulting the `.tune` files for the appropriate versions
  to pull in.
- Configure with `cmake -G=Ninja -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DLUTE_STDLESS=ON`
  to build a version with no embedded Luau functionality.
- Build a `lute` executable with `ninja -C build lute/cli/lute` or our test suite with
  `ninja -C build tests/lute-tests`.
- Optionally, use this version to run `luthier generate` to generate the embedded Luau source files, then reconfigure
  without `-DLUTE_STDLESS=ON` and rebuild to get a fully-featured `lute`.

### CCache support

Lute supports the use of ccache to speed up builds. Both the `bootstrap` and `luthier` build scripts support a
`--with-ccache` option, which proxies all compilation through ccache. To benefit from caching during local development,
download ccache using your systems package manager (apt/brew/choco/etc), and perform a clean configure with
`--with-ccache` passed. Subsequent builds will then use the cached build artifacts in the .ccache directory.
Additionally, you'll need to set the following variables:

```
CCACHE_DIR=path/to/store/ccachedir
CCACHE_MAXSIZE=maximum size of the cache
CCACHE_COMPRESS=true
```
