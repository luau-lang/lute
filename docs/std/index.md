---
order: 3
---

# (@std) Standard Library
The Lute Standard Library is a set of common utilities that you will almost
certainly want to reach for when writing programs in Luau. The modules in this
library are broadly categorized as follows:
1. Luau internals - AST(Abstract Syntax Tree APIs), working with the VM,
   typechecking
2. I/O - talking to the file system, processes, networking
3. Platform abstractions - e.g. path, time, tasks
4. Miscellaneous utilities - libraries for tables, strings, json, testing

When writing programs against the standard library, you can require them using
the reserved alias `@std`:
```luau
local _ = require("@std/json")
```