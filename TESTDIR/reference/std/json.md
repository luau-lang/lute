# json

```luau
local json = require("@std/json")
```

## json.asarray

```luau
(nil | number | string | boolean | { [number]: any } | { [string]: any }) -> ({ [number]: any } | nil)
```

## json.asobject

```luau
(nil | number | string | boolean | { [number]: any } | { [string]: any }) -> ({ [string]: any } | nil)
```

## json.deserialize

```luau
(string) -> ({ [number]: any } | { [string]: any } | boolean | number | string | nil)
```

## json.null

```luau
nil
```

## json.object

```luau
({ [string]: any }) -> ({ [string]: any })
```

## json.serialize

```luau
(nil | number | string | boolean | { [number]: any } | { [string]: any }, boolean | nil) -> (string)
```
