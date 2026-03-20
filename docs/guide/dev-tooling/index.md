---
order: 6
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