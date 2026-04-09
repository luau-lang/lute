# posix

```luau
local posix = require("@std/path/posix")
```

## posix.basename

```luau
(path: Pathlike) -> string?
```

## posix.dirname

```luau
(path: Pathlike) -> string
```

## posix.extname

```luau
(path: Pathlike) -> string
```

## posix.format

```luau
(path: Pathlike) -> string
```

## posix.isAbsolute

```luau
(path: Pathlike) -> boolean
```

## posix.join

```luau
(...: Pathlike) -> Path
```

## posix.normalize

```luau
(path: Pathlike) -> Path
```

## posix.parse

```luau
(path: Pathlike) -> Path
```

## posix.pathmt

```luau
pathinterface.PathInterface
```

## posix.pathmt:__tostring

```luau
() -> string
```

## posix.relative

```luau
(from: Pathlike, to: Pathlike) -> Path
```

## posix.resolve

```luau
(...: Pathlike) -> Path
```
