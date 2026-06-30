# lint

`lute lint` is a programmable linter for Luau code, shipped as part of Lute.
As a linter, it works to statically analyze the user's code to warn them about common pitfalls they may be falling into, or to nudge them away from discouraged coding practices.
It is _programmable_ meaning that you can write a new lint rule for your Luau code _in Luau_.
It's also built on top of the official Luau language stack, allowing it to leverage the same parser used by Luau and Roblox, unlike third-party linters that rely on separate, custom parser implementations.
The examples folder contains two instances of sample lint rules.
You can find the full suite of `lute lint`'s default rules documented as sub-pages of this page and their source code [here](https://github.com/luau-lang/lute/tree/primary/lute/cli/commands/lint/rules).

## Usage

```bash
lute lint [OPTIONS] [...PATHS]
```

## Options

### `-h, --help`

Show this help message

### `-v, --verbose`

Enable verbose output

### `-r, --rules [RULE]`

Path to a single lint rule or a folder containing lint rules. If a folder is provided, any subfolders containing init.luau files will be treated as modules exporting lint rules, while all other .luau files will be treated as individual lint rules. If unspecified, the default lint rules are used.

### `-c, --config [CONFIG]`

Path to file containing lute lint configuration table. If unspecified, lute lint will look for a `.config.luau` file in the working directory from which it is invoked.

Configuration expects the following structure:
```luau
type RuleName = string

type Config = {
    lute: {
        lint: {
            -- Array of globs (.gitignore style) to EXEMPT from linting
            ignores: { string }?,
            -- Table of string:unknown pairs; globals are passed down to each rule
            globals: { [string]: unknown }?,
            -- Array of paths from which to load local lint rules (similar to -r CLI option)
            rulepaths: { [string] }?,
            -- Specify per-rule options and overrides
            ruleconfigs: {
                [RuleName]: {
                    -- Array of globs (.gitignore style) that are EXEMPT from this rule
                    ignores: { string }?,
                    -- Override a rule's default severity
                    severity: ("warning" | "error" | "info" | "hint")?,
                    -- Pass custom options through to a rule;
                    -- see specific rule's implementation / docs for expected options structure
                    options: { [string]: unknown }?,
                    -- Disable a rule
                    off: boolean?,
                },
            }?,
            -- Apply lint configuration only to files matching one of the override's paths
            overrides: {
                {
                    -- Array of globs (.gitignore style) that select files for this override
                    paths: { string },
                    -- Overrides support the same fields as the top-level lint config
                    ignores: { string }?,
                    globals: { [string]: unknown }?,
                    rulepaths: { [string] }?,
                    ruleconfigs: {
                        [RuleName]: {
                            ignores: { string }?,
                            severity: ("warning" | "error" | "info" | "hint")?,
                            options: { [string]: unknown }?,
                            off: boolean?,
                        },
                    }?,
                },
            }?,
        }?,
    }?,
}
```

#### Config Overrides

Use `overrides` to apply lint configuration to specific paths in a repo. Each override has a required `paths` array containing `.gitignore`-style globs. When a file matches any glob in an override's `paths`, that override is applied for that file.

Overrides are evaluated in order and are cumulative. If multiple overrides match a file, later overrides are merged on top of earlier ones.

Merge behavior:

- `ignores`, rule-specific `ignores`, and `rulepaths` are appended.
- `globals` are shallow-merged, with later values replacing earlier values for the same key.
- `ruleconfigs` are merged one level per rule. For example, an override can add `severity = "error"` to a rule while preserving that rule's existing `options`.

ADD EXAMPLE
```

### `-j, --json`

Output lint violations in JSON format matching the LSP diagnostic spec.

### `-s, --string-input`

Lint the provided string input instead of reading from files.

### `--sequential`

Lint files sequentially instead of in parallel.

### `--auto-fix`

Automatically apply fixes for lint violations that provide a suggested fix. Assumes that suggested fixes do not overlap. Does nothing when linting string input.

### `--no-default-lints`

Disables the default lint rules.

## Arguments

Path(s) to the Luau file(s) or folders containing Luau files to be linted. Only files with .luau or .lua extensions will be linted.

## Examples

```bash
lute lint -r examples/lints/almost_swapped.luau bad_swap.luau
```

```bash
lute lint -r examples/lints/ lintee.luau src_code/
```
