# duplicate_keys

This lint rule checks for uses of duplicate keys in table literals.
This includes map-like entries that may collide with array-like entries.

## Why this is discouraged

This pattern is most likely the result of a mistake, and the final table value will only use one of the values assigned to a duplicate key.

## Example violations

`duplicate_keys` will warn on the following:

```luau
local t = {
    key = 1,
    ["key"] = 2,
    "array-like-value1",
    "array-like-value2",
    [2] = "map-like-value"
}
```
