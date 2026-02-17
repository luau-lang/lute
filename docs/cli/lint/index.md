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

### `-j, --json`

Output lint violations in JSON format matching the LSP diagnostic spec.

### `-s, --string-input`

Lint the provided string input instead of reading from files.

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
