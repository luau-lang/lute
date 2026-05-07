# format

Format Luau source files with Lute's built-in formatter.

## Usage

```bash
lute format [options...] <paths...>
```

If no paths are provided, `lute format` formats the current directory. Directories are searched recursively for `.luau` and `.lua` files.

Use `-` as the only path to read from stdin and write formatted source to stdout.

## Options

### `--check`

Reports files that would change without writing them. The command exits with status code `1` if any file is not formatted or if formatting fails.

## Configuration

`lute format` intentionally does not read `.stylua.toml`, `.editorconfig`, environment variables, editor settings, or user configuration files. Formatting uses Lute's fixed policy, with existing newlines treated as layout signals where the formatter can choose between single-line and multiline output.
