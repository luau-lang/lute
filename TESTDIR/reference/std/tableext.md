# tableext

```luau
local tableext = require("@std/tableext")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [all](#tableextall) | Returns `true` if `predicate` returns `true` for every element of `arr`. |
| [any](#tableextany) | Returns `true` if `predicate` returns `true` for at least one element of `arr`. |
| [combine](#tableextcombine) | Merges all additional tables into `tbl` in order. When the same key appears in multiple tables, the value from the last table containing that key wins. Returns `tbl`. |
| [extend](#tableextextend) | Appends all elements from each additional array into `tbl` in order, mutating it in place. |
| [filter](#tableextfilter) | Returns a new table containing only the key-value pairs from `table` for which `predicate` returns `true`. |
| [keys](#tableextkeys) | Returns an array of all keys in `tbl`. Order is not guaranteed. |
| [map](#tableextmap) | Returns a new table with the same keys as `table`, where each value has been transformed by applying `f` to it. |
| [reverse](#tableextreverse) | Returns `tbl` with its elements in reverse order. If `inplace` is `true`, reverses `tbl` in place; otherwise returns a new array. |
| [toSet](#tableexttoset) | Converts an array into a set-like table where each element maps to `true`. |

---

## Functions and Properties

### tableext.all

Returns `true` if `predicate` returns `true` for every element of `arr`.

```luau
(arr: { T }, predicate: (T) -> boolean) -> boolean
```

---

### tableext.any

Returns `true` if `predicate` returns `true` for at least one element of `arr`.

```luau
(arr: { T }, predicate: (T) -> boolean) -> boolean
```

---

### tableext.combine

Merges all additional tables into `tbl` in order. When the same key appears in multiple tables, the value from the last table containing that key wins. Returns `tbl`.

```luau
(tbl: { [K]: V }, ...: { [K]: V }) -> { [K]: V }
```

---

### tableext.extend

Appends all elements from each additional array into `tbl` in order, mutating it in place.

```luau
(tbl: { T }, ...: { T }) -> ()
```

---

### tableext.filter

Returns a new table containing only the key-value pairs from `table` for which `predicate` returns `true`.

```luau
(table: { [K]: V }, predicate: (V) -> boolean) -> { [K]: V }
```

---

### tableext.keys

Returns an array of all keys in `tbl`. Order is not guaranteed.

```luau
(tbl: { [K]: V }) -> { K }
```

---

### tableext.map

Returns a new table with the same keys as `table`, where each value has been transformed by applying `f` to it.

```luau
(table: { [K]: A }, f: (A) -> B) -> { [K]: B }
```

---

### tableext.reverse

Returns `tbl` with its elements in reverse order. If `inplace` is `true`, reverses `tbl` in place; otherwise returns a new array.

```luau
(tbl: { T }, inplace: boolean?) -> { T }
```

---

### tableext.toSet

Converts an array into a set-like table where each element maps to `true`.

```luau
(tbl: { T }) -> { [T]: true }
```

---
