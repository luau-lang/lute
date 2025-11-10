# Contributing to Lute

## Getting Started

First off, thank you for your interest in contributing to Lute!
We're really excited about building a powerful standalone runtime for Luau, and we're glad that you are too!
Whether you're fixing bugs, improving our documentation, or posting feature requests, we value your contributions!
If you're interested in contributing code in particular, please continue reading this document and
check out the [open issues](https://github.com/luau-lang/lute/issues) on our issue tracker for possible avenues to contribute!

## Ways to Contribute

- **Bug Reports:** Please open a [GitHub Issue](https://github.com/luau-lang/lute/issues/new) with a clear description, label, and reproduction steps.
- **Feature Requests:** Open an issue with your idea and rationale.
- **Code Contributions:** Fork this repository, create a branch, and submit a PR (see "Code Guidelines" below).

## Repository Structure

Lute as a project is organized to use [GitHub](https://github.com/luau-lang/lute) for issue tracking, project milestones, managing contributions, and so forth.
Lute's [documentation site](https://luau-lang.github.io/lute) is also built from this repository, and accepts pull requests just like any other code does.

Navigating the repository benefits from knowing its structure, namely:
-  Source code lives in the [`/lute/`](./lute) directory,
-  type definitions are in [`/definitions/`](./definitions),
-  user-facing documentation is defined in [`/docs/`](./docs),
-  supporting tooling for working on lute is provided in [`/tools/`](./tools), and finally,
-  tests can be found in the [`/tests/`](./tests/) directory.

As a codebase, Lute consists of three components:
1. The runtime itself, written in C++, defined in various modules under `/lute/` and accessible from Luau scripts via `require("@lute/module")`.
   These runtime libraries provide core functionality that extends the expressivity of Luau itself, and allows programmers to write general-purpose programs at all.
2. The standard library, written in Luau, defined under `/lute/std/libs` and _embedded into the Lute executable_.
   The standard library provides a general interface for programming in Luau, one that we strive to make as delightful as it can be.
   It includes both wrappers of runtime functionality that allow runtime authors to support cross-runtime code, as well as
   general Luau libraries that improve the developer experience and increase developer productivity on new projects.
3. batteries, written in Luau, defined in various modules under `/batteries/` which are not included in any formal distribution of Lute.
   A goal of Lute as a project is to build the foundations for a healthy open source ecosystem for Luau, and achieving that means building
   core developer tooling like _a package manager_. In the mean time, we need to write some Luau code to help us build the future, and we
   need a place for it to live. batteries are exactly that! Useful Luau code that should run everywhere, and that we can use to build our tooling.
   Once Luau has a proper package manager built on Lute, batteries will be pulled out of the repository and made available as a separate package.

## Code Guidelines

In the interest of having a consistent standard for code, we expect that incoming contributions will follow existing code styling.
In support of this, we've provided appropriate configuration for autoformatter tools to help enforce this.
For C++ code, we provide a `.clang-format` file; please make sure to format your code before opening a PR.
All Luau scripts should be formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua).

There are some additional style considerations that we do not have automated enforcement for today, but that we will address in reviews:

1. All Luau APIs exposed publically by Lute in both the runtime and the standard library must have identifiers written in `luacase`.
   This means module names, function names, table fields, exported types, etc. should be written in all lowercase, and should be named ideally with
   one or two words succinctly. We know this style is not everyone's favorite, and we do not advocate for external software to use it, but we would like
   to retain consistency with Luau's builtin library which inherits this convention from Lua.
2. All other Luau code, including the internals of those Luau APIs, should be written using `camelCase` for identifiers and table fields, and `PascalCase` for type names.
3. Every functionality change should come with tests that express the desired behavior of the code being added.
4. Tests should be placed along side existing tests, and use the appropriate testing tools provided for Lute.
   C++ code should be tested using `doctest` and linked into a test executable.
   Luau code should be tested using Lute's testing framework, and should be written in a `.test.luau` file.
5. Small, incremental contributions are always preferred over sweeping changes. You should expect that any large sweeping change will be rejected summarily without review.
   If you're interested in working on something that _requires_ such a change, you should open an issue first to discuss the idea and get buy-in from the team.

## Licensing

By providing code in an issue or opening a pull request, you agree to license that code under the MIT License, and indicate that you have the legal right to do so.
