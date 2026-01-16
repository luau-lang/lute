---
order: 2
---

# CLI Reference

Lute provides a command-line interface for running, type checking, compiling, testing, and linting Luau code.

## Usage

```bash
lute <command> [options] [arguments...]
```

If no command is specified, `run` is used by default.

## Commands

| Command | Description |
| ------- | ----------- |
| [check](./check) | Type check Luau files. |
| [compile](./compile) | Compile a Luau script into a standalone executable. |
| [lint](./lint) | Lint the specified Luau file using the specified lint rule(s) or using the default rules. |
| [run](./run) | Run a Luau script. |
| [setup](./setup) | Generate type definition files for the language server. |
| [test](./test) | Run tests discovered in .test.luau and .spec.luau files. |
| [transform](./transform) | Run a specified code transformation on specified Luau files. |

## Global Options

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Display help message for the command. |
| `--version` | Show the lute version. |
