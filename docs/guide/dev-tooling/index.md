---
order: 7
---

# Developer Tooling

We've invested considerable effort in the developer tooling experience for users
writing Luau with Lute. This section summarizes some of the tools you may want
to consider using on a day to day basis.

## [Testing](../../cli/test)

`lute test` is a builtin utility for discovering and running tests. Tests are
written using the `@std/test` library in `.spec.luau` or `.test.luau` files, in
a `tests/` directory and `lute test` will handle discovering and running these
tests for you.



## [Linting](../../cli/lint/index.md)

lute lint is a programmable linter for Luau code, shipped as part of Lute. It is programmable - you can write custom rules for your repository in Luau. It ships with a number of builtin rules, which you can run on your current directory with `lute lint`. For more information, check out the [lint documentation](../../cli/lint/index.md)!
