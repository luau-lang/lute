# query

```luau
local query = require("@std/syntax/query")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [filter](#queryfilter) | Retains only the nodes for which `pred` returns `true`. Mutates and returns the query. |
| [findAll](#queryfindall) | Recursively visits every descendant of each node in the query and collects those for which `fn` returns a non-nil value. Mutates and returns the query. |
| [findAllFromRoot](#queryfindallfromroot) | Creates a new `Query` by visiting every node in `ast` and collecting those for which `fn` returns a non-nil value. |
| [flatMap](#queryflatmap) | Replaces each node with the array of values returned by `fn`, flattening one level. Mutates and returns the query. |
| [forEach](#queryforeach) | Calls `callback` on each node. Returns the query unchanged for chaining. |
| [map](#querymap) | Replaces the query's nodes with the non-nil values returned by `fn` for each node. Mutates and returns the query. |
| [mapToArray](#querymaptoarray) | Returns a plain array of the non-nil values produced by calling `fn` on each node. Does not mutate the query. |
| [replace](#queryreplace) | Calls `repl` on each node and collects the non-nil results into a `Replacements` table for use with the printer. |

---

## Functions and Properties

### query.filter

Retains only the nodes for which `pred` returns `true`. Mutates and returns the query.

```luau
(self: Query<T>, pred: (T) -> boolean) -> Query<T>
```

---

### query.findAll

Recursively visits every descendant of each node in the query and collects those for which `fn` returns a non-nil value. Mutates and returns the query.

```luau
(self: Query<T>, fn: (Node) -> U?) -> Query<U>
```

---

### query.findAllFromRoot

Creates a new `Query` by visiting every node in `ast` and collecting those for which `fn` returns a non-nil value.

```luau
(ast: types.ParseResult | Node, fn: (Node) -> T?) -> Query<T>
```

---

### query.flatMap

Replaces each node with the array of values returned by `fn`, flattening one level. Mutates and returns the query.

```luau
(self: Query<T>, fn: (T) -> { U }) -> Query<U>
```

---

### query.forEach

Calls `callback` on each node. Returns the query unchanged for chaining.

```luau
(self: Query<T>, callback: (T) -> ()) -> Query<T>
```

---

### query.map

Replaces the query's nodes with the non-nil values returned by `fn` for each node. Mutates and returns the query.

```luau
(self: Query<T>, fn: (T) -> U?) -> Query<U>
```

---

### query.mapToArray

Returns a plain array of the non-nil values produced by calling `fn` on each node. Does not mutate the query.

```luau
(self: Query<T>, fn: (T) -> U?) -> { U }
```

---

### query.replace

Calls `repl` on each node and collects the non-nil results into a `Replacements` table for use with the printer.

```luau
(self: Query<T>, repl: (T) -> string?) -> types.Replacements
```

---
