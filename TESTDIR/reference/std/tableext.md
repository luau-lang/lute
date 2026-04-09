# tableext

```luau
local tableext = require("@std/tableext")
```

## tableext.all

```luau
(arr: { T }, predicate: (T) -> boolean) -> boolean
```

## tableext.any

```luau
(arr: { T }, predicate: (T) -> boolean) -> boolean
```

## tableext.combine

```luau
(tbl: { [K]: V }, ...: { [K]: V }) -> { [K]: V }
```

## tableext.extend

```luau
(tbl: { T }, ...: { T }) -> ()
```

## tableext.filter

```luau
(table: { [K]: V }, predicate: (V) -> boolean) -> { [K]: V }
```

## tableext.keys

```luau
(tbl: { [K]: V }) -> { K }
```

## tableext.map

```luau
(table: { [K]: A }, f: (A) -> B) -> { [K]: B }
```

## tableext.reverse

```luau
(tbl: { T }, inplace: boolean?) -> { T }
```

## tableext.toSet

```luau
(tbl: { T }) -> { [T]: true }
```
