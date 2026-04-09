# query

```luau
local query = require("@std/syntax/query")
```

## query.filter

```luau
(self: Query<T>, pred: (T) -> boolean) -> Query<T>
```

## query.findAll

```luau
(self: Query<T>, fn: (Node) -> U?) -> Query<U>
```

## query.findAllFromRoot

```luau
(ast: types.ParseResult | Node, fn: (Node) -> T?) -> Query<T>
```

## query.flatMap

```luau
(self: Query<T>, fn: (T) -> { U }) -> Query<U>
```

## query.forEach

```luau
(self: Query<T>, callback: (T) -> ()) -> Query<T>
```

## query.map

```luau
(self: Query<T>, fn: (T) -> U?) -> Query<U>
```

## query.mapToArray

```luau
(self: Query<T>, fn: (T) -> U?) -> { U }
```

## query.replace

```luau
(self: Query<T>, repl: (T) -> string?) -> types.Replacements
```
