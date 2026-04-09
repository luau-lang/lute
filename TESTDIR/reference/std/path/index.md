# path

```luau
local path = require("@std/path")
```

## path.basename

```luau
(path: Pathlike) -> string?
```

## path.dirname

```luau
(path: Pathlike) -> string
```

## path.extname

```luau
(path: Pathlike) -> string
```

## path.format

```luau
(path: Pathlike) -> string
```

## path.isAbsolute

```luau
(path: Pathlike) -> boolean
```

## path.join

```luau
(...: Pathlike) -> Path
```

## path.normalize

```luau
(path: Pathlike) -> Path
```

## path.parse

```luau
(path: Pathlike) -> Path
```

## path.relative

```luau
(from: Pathlike, to: Pathlike) -> Path
```

## path.resolve

```luau
(...: Pathlike) -> Path
```
