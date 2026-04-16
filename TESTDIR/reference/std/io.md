# io

```luau
local io = require("@std/io")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [input](#ioinput) | Reads a line from standard input. If `prompt` is provided, it is written to stdout before waiting for input. |
| [write](#iowrite) | Writes one or more strings to standard output without a trailing newline. |

---

## Functions and Properties

### io.input

Reads a line from standard input. If `prompt` is provided, it is written to stdout before waiting for input.

User input can be provided via command line stdin, piped input, or redirection from a file. See `examples/user_input.luau`.

```luau
(prompt: string?) -> string
```

---

### io.write

Writes one or more strings to standard output without a trailing newline.

```luau
(...: string) -> ()
```

---
