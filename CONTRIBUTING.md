# Contributing to Lute

Whether you're fixing bugs, improving our documentation, or posting feature requests, we value your contributions! ❤️

## How You Can Contribute

- **Bug Reports:** Please open a [GitHub Issue](https://github.com/luau-lang/lute/issues/new) with a clear description, label, and reproduction steps.
- **Feature Requests:** Open an issue with your idea and rationale.
- **Code Contributions:** Fork this repository, create a branch, and submit a PR (see “Code Guidelines below).

## Code Guidelines

Feel free to take a look at our [open issues](https://github.com/luau-lang/lute/issues) if you're interested in contributing!

Source code lives within the [lute](./lute) directory, type definitions are in [definitions](./definitions), and tests can be found in [tests](./tests/).

Contributions are expected to follow the existing code style.
For C++ code, we provide a `.clang-format` file; please make sure to format your code before opening a PR.
All Luau scripts should be formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua).

Naming for public-facing APIs:
- Luau-facing runtime APIs (module names, function names, table fields, etc.) and exported type names must use luacase; for example, `fs.readfiletostring`.
- Internal implementation details may use other styles where already established.

Testing:
- Always add tests unless you have a strong reason not to do so. If so, please note this in your PR description.
- Place new tests alongside existing tests and follow established test patterns.
- Luau test files should have a `.test.luau` extension: these files are automatically picked up during CI.

In general, small, incremental changes are preferred over large refactors.

## Licensing
By submitting a contribution, you agree to license it under the MIT License and represent that you have the right to do so.
