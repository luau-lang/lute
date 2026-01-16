# lint

Lint the specified Luau file using the specified lint rule(s) or using the default rules.

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

## Arguments

Path(s) to the Luau file(s) or folders containing Luau files to be linted. Only files with .luau or .lua extensions will be linted.

## Examples

```bash
lute lint -r examples/lints/almost_swapped.luau bad_swap.luau
```

```bash
lute lint -r examples/lints/ lintee.luau src_code/
```
