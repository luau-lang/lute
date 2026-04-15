---
order: 3
---

# (@std) Standard Library
The Lute Standard Library is a set of common utilities that you will almost
certainly want to reach for when writing programs in Luau. In order to make Luau
useful for general-purpose programming, Lute provides a standard library, under
the alias `@std`, that aims to provide all the necessary utilities to help you
author useful programs! Beyond being useful, we aim for this collection of
libraries to be high-level and readily implementable by other Luau runtime
environments to enable more compatibility within our ecosystem. We are actively
working towards integrating these libraries into the most-used Luau runtime,
Roblox. The modules in this library are broadly categorized as follows:

1. Interacting with the language -- parsing Luau, interacting with the compiler,
   virtual machine, and type checker.
2. I/O -- talking to the world outside of the program, including the command
   line, the file system, external processes, the network, etc.
3. Platform abstractions -- e.g. file system path, measures of time, and
   cooperative multitasking
4. General programming utilities - libraries for interacting with tables,
   strings, json, and testing your code

When writing programs against the standard library, you can require them using
the reserved alias `@std`:
```luau
local _ = require("@std/json")
```