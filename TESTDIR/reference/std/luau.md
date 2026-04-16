# luau

```luau
local luau = require("@std/luau")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Bytecode](#bytecode) | Compiled Luau bytecode produced by `luau.compile`. |
| [RequireNode](#requirenode) |  |
| [Type](#type) | A Luau type, representing the type of a value or expression. |
| [TypePack](#typepack) | A Luau type pack, representing a sequence of types. |
| [compile](#luaucompile) | Compiles Luau source code into bytecode. |
| [load](#luauload) | Loads `bytecode` into a callable function. `chunkname` names the chunk for error messages. |
| [loadModule](#luauloadmodule) | Loads and executes the Luau file at `requirePath`, returning its result. |
| [requires](#luaurequires) |  |
| [resolveModule](#luauresolvemodule) | Resolves the require path `modulepath` relative to `frompath`, returning the absolute path. |
| [typeofModule](#luautypeofmodule) | Returns the type pack representing the return types of the module at `modulepath`, or `nil` if unavailable. |

---

## Types

### Bytecode

Compiled Luau bytecode produced by `luau.compile`.

```luau
type Bytecode = luteLuau.Bytecode
```

---

### RequireNode

```luau
type RequireNode = {
	resolvedPath: string?,
	requirePath: string?,
	requireExpr: luteLuau.AstExprCall,
}
```

---

### Type

A Luau type, representing the type of a value or expression.

```luau
type Type = luteLuau.Type
```

---

### TypePack

A Luau type pack, representing a sequence of types.

```luau
type TypePack = luteLuau.TypePack
```

---

## Functions and Properties

### luau.compile

Compiles Luau source code into bytecode.

```luau
(source: string) -> Bytecode
```

---

### luau.load

Loads `bytecode` into a callable function. `chunkname` names the chunk for error messages.

An optional `env` table can be provided to override the global environment for the loaded chunk.

```luau
(bytecode: Bytecode, chunkname: string?, env: { [any]: any }?) -> (...any) -> ...any
```

---

### luau.loadModule

Loads and executes the Luau file at `requirePath`, returning its result.

An optional `env` table can be provided to override the global environment.

```luau
(requirePath: path.Pathlike, env: { [any]: any }?) -> any
```

---

### luau.requires

```luau
(filePath: path.Pathlike) -> { RequireNode }
```

---

### luau.resolveModule

Resolves the require path `modulepath` relative to `frompath`, returning the absolute path.

```luau
(modulepath: string, frompath: path.Pathlike) -> path.Pathlike
```

---

### luau.typeofModule

Returns the type pack representing the return types of the module at `modulepath`, or `nil` if unavailable.

```luau
(modulepath: path.Pathlike) -> TypePack?
```

---
