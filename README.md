Lute [![CI](https://github.com/luau-lang/lute/actions/workflows/ci.yml/badge.svg)](https://github.com/luau-lang/lute/actions/workflows/ci.yml)
====

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

### Building Lute from scratch

Lute uses a script built in Luau to handle pulling in vendored dependencies and embedding our Luau standard library into the `lute` executable. As a result, you typically need a `lute` executable available already in order to build it. As a result, you'd like to build `lute` entirely from scratch, you'll have to bootstrap it.
From the root directory, run `./tools/bootstrap.sh` to build a `lute` executable. If you pass the `--install` flag, this will be
installed to `$HOME/.lute/bin/lute` by default, with a prompt provided to select an alternative install location. Make sure to add this `lute` to your `$PATH` if you would like to have `lute` resolve to it in general.

### Building Lute with `lute` installed

After either bootstrapping `lute` per above or installing it using `foreman`, `rokit`, or manually from Releases, you can build modified local versions of `lute` using our build script, `luthier`, located at `./tools/luthier.luau`. To perform a clean build of Lute, you can run:
```bash
/path/to/lute tools/luthier.luau build --clean {lute | Lute.CLI | Lute.tests}
```

## Manually building Lute

Outside of resolving the dependencies, Lute's build system is implemented today with `cmake`, meaning you can fairly easily pull external dependencies into `extern`, and then perform your own manual build with the following steps:

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
