# win32

```luau
local win32 = require("@std/path/win32")
```

## win32.basename

```luau
(path: Pathlike) -> string?
```

## win32.dirname

```luau
(path: Pathlike) -> string
```

## win32.drive

```luau
(path: Pathlike) -> Path
```

## win32.extname

```luau
(path: Pathlike) -> string
```

## win32.format

```luau
(path: Pathlike) -> string
```

## win32.isAbsolute

```luau
(path: Pathlike) -> boolean
```

## win32.join

```luau
(...: Pathlike) -> Path
```

## win32.normalize

```luau
(path: Pathlike) -> Path
```

## win32.parse

```luau
(path: Pathlike) -> Path
```

## win32.pathmt

```luau
pathinterface.PathInterface
```

## win32.pathmt:__tostring

```luau
() -> string
```

## win32.relative

```luau
(from: Pathlike, to: Pathlike) -> Path
```

## win32.resolve

```luau
(...: Pathlike) -> Path
```
