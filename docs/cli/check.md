# check

Type check Luau files.

## Usage

```bash
lute check <file1.luau> [file2.luau...]
```

## Configuration

Set `lute.check.ignores` in `.config.luau` to skip input files that match the listed glob patterns. Patterns are relative to the configuration file.

```luau
return {
	lute = {
		check = {
			ignores = { "**/*.d.luau", "**/*.snap.luau" },
		},
	},
}
```

## Options

### `-h, --help`

Display this usage message.
