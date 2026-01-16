# compile

Compile a Luau script into a standalone executable.

## Usage

```bash
lute compile <entry.luau> [options]
```

## Options

### `--output <path>`

Name for the compiled executable. Defaults to entry file's base name (with .exe on Windows).

### `--bundle-stats`

Display bundle size and compression statistics.

### `--show-require-graph`

Print the require dependency graph.

### `-h, --help`

Display this usage message.
