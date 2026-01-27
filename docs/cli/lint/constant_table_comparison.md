---
title: constant_table_comparison
---
# constant_table_comparison

This lint rule checks for instances of attempting to compare to table literals.

## Why this is discouraged

This will never result in the expected behavior.
In Luau, tables are stored and compared by *reference*, rather than by value.
This means that when you compare two variables containing tables, Luau will compare whether the two variables point to the same table in memory, rather than recursively comparing their keys and values.
When you compare to a table literal (i.e. `if x == { a = 3 } then ... end`), Luau will create a new table with a single entry (`a = 3`) in memory and check whether `x` references that table.
Since the table is newly created (and there wasn't even the chance to reassign `x` to that table) this comparison will always evaluate to `false`.

## Example violations

`constant_table_comparison` will warn on the following:

```luau
if x == {} then
    ...
elseif x ~= {} then
    ...
end
```

You should instead do:

```luau
if next(x) == nil then
    ...
elseif next(x) ~= nil then
    ...
end
```
