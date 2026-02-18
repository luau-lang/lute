# posix

```luau
local posix = require("@std/path/posix")
```

## posix.basename

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string | nil)
```

## posix.dirname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string)
```

## posix.extname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string)
```

## posix.format

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string)
```

## posix.isabsolute

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (boolean)
```

## posix.join

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } })
```

## posix.normalize

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } })
```

## posix.parse

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } })
```

## posix.pathmt

```luau
{ __tostring: (<recursive>) -> (string) }
```

## posix.relative

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } })
```

## posix.resolve

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } })
```
