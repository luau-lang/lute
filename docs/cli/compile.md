# compile

Compile a Luau script, along with its dependencies, into a standalone executable.

## Usage

```bash
lute compile <entry.luau> [options]
```

## Options

### `--output <path>`

Name for the compiled executable. If omitted, defaults to entry file's base name (with .exe on Windows).

### `--bundle-stats`

Display compiled bytecode bundle size and compression statistics.

### `--show-require-graph`

Print the dependency graph of files that have been included in the bundle.

### `-h, --help`

Display this usage message.

## Examples

Outputs a standalone executable called foo(.exe on windows):

```bash
lute compile foo.luau
```

Outputs a standalone executable called main(.exe on windows):

```bash
lute compile foo.luau --output main
```