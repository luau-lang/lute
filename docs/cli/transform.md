# transform

Run a specified code transformation on specified Luau files.
Individual code transformers can specify custom migration options, which are parsed as additional arguments on the command line (i.e. `lute transform transformer.luau --custom-arg=value transformee.luau`).

## Usage

```bash
lute transform <transformer script> [options...] <files...>
```

## Options

### `--dry-run`

Runs the transformation without actually overwriting or deleting any files.

### `--output <path>`

Specifies an output file for a transformed file. Only valid when transforming a single file. If not specified, files are overwritten in place.
