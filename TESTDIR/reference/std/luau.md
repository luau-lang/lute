# luau

```luau
local luau = require("@std/luau")
```

## luau.compile

```luau
(source: string) -> Bytecode
```

## luau.load

```luau
(bytecode: Bytecode, chunkname: string?, env: { [any]: any }?) -> (...any) -> ...any
```

## luau.loadModule

```luau
(requirePath: path.Pathlike, env: { [any]: any }?) -> any
```

## luau.resolveModule

```luau
(modulepath: string, frompath: path.Pathlike) -> path.Pathlike
```

## luau.typeofModule

```luau
(modulepath: path.Pathlike) -> (TypePack, {[string]: Type})
```
