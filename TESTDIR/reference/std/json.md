# json

```luau
local json = require("@std/json")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [Array](#array) | A JSON array: a table with integer keys. |
| [Object](#object) | A JSON object: a table with string keys. |
| [Value](#value) | Any JSON value: `null`, a number, string, boolean, array, or object. |
| [asArray](#jsonasarray) | Returns `value` as an `Array` if it is a JSON array, or `nil` otherwise. |
| [asObject](#jsonasobject) | Returns `value` as an `Object` if it is a JSON object, or `nil` otherwise. |
| [deserialize](#jsondeserialize) | Parses a JSON string and returns the corresponding Luau value. Returns `json.null` for a JSON `null` literal; compare with `json.null` rather than `nil` to check for null. |
| [object](#jsonobject) | Creates a JSON `Object` from `props`. Use this to distinguish an empty object `{}` from an empty array when serializing. |
| [serialize](#jsonserialize) | Serializes `value` to a JSON string. If `prettyPrint` is `true`, the output is indented for readability. |

---

## Types

### Array

A JSON array: a table with integer keys.

```luau
type Array = { [number]: Value }
```

---

### Object

A JSON object: a table with string keys.

```luau
type Object = { [string]: Value }
```

---

### Value

Any JSON value: `null`, a number, string, boolean, array, or object.

```luau
type Value = nil | number | string | boolean | Array | Object
```

---

## Functions and Properties

### json.asArray

Returns `value` as an `Array` if it is a JSON array, or `nil` otherwise.

```luau
(value: Value) -> Array?
```

---

### json.asObject

Returns `value` as an `Object` if it is a JSON object, or `nil` otherwise.

```luau
(value: Value) -> Object?
```

---

### json.deserialize

Parses a JSON string and returns the corresponding Luau value. Returns `json.null` for a JSON `null` literal; compare with `json.null` rather than `nil` to check for null.

```luau
(src: string) -> (Array | Object | boolean | number | string)?
```

---

### json.object

Creates a JSON `Object` from `props`. Use this to distinguish an empty object `{}` from an empty array when serializing.

```luau
(props: { [string]: Value }) -> Object
```

---

### json.serialize

Serializes `value` to a JSON string. If `prettyPrint` is `true`, the output is indented for readability.

```luau
(value: Value, prettyPrint: boolean?) -> string
```

---
