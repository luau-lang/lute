# json

```luau
local json = require("@std/json")
```

## json.asArray

```luau
(value: Value) -> Array?
```

## json.asObject

```luau
(value: Value) -> Object?
```

## json.deserialize

```luau
(src: string) -> (Array | Object | boolean | number | string)?
```

## json.object

```luau
(props: { [string]: Value }) -> Object
```

## json.serialize

```luau
(value: Value, prettyPrint: boolean?) -> string
```
