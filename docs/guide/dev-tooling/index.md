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

`lute lint` is a programmable linter built atop the code transformation
infrastructure we've designed. This linter is extensible - you can download
additional rules, or even write your own to add custom lints for your
repository. Think of this as a super powerful spellchecker. To get started, you
can invoke this tool with:
```bash
lute lint
```
to get a report on your repositories conformance to the builtin lint rules. You
can configure the linter with a `lint.config.luau` file with the following
schema:
```luau
return { -- within .config.luau
  ...,
  lute: {
    lint: {
      ignores: { string }, -- file globs to exempt from linting
      globals: { [string] : unknown }, -- custom globals that are passed to all rules thru context
      rules: {
        -- list of relative paths to rules defined in the project / on local device
        paths: { path.pathlike },
        -- configuration for specific rules
        [string]: {
          off: true? -- turn off rules; defaults to false
          severity: ("info" | "hint" | "warn" | "error")?, -- overwrite severity; defaults to rule's returned violation severity
          options: unknown?, -- custom options, defined individually in rule implementations.
          ignores: { string }?, -- file globs that this rule should specifically ignore
        }
      }
    },
    ...
  }
}
```

To pass configuration, you can run the linter with `--config/-c path/to/config`.
`lute lint` also supports a `--fix` argument, that will automatically fix
violations for your.

- TODO: add linter format documentation
- TODO: add explanation of how / where to add custom rules
