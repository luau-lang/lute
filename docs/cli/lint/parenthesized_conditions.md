# parenthesized_conditions

This lint rule checks for instances where the conditions of syntactic structures like if statements, while loops, and repeat loops have parenthesized conditions.

## Why this is discouraged

Although there is no semantic difference, the parentheses are unidiomatic and may detract from readability.

## Example violations

`parenthesized_conditions` will warn on the following:

```luau
if (x > 5) then
    ...
end
```

You should instead do:

```luau
if x > 5 then
    ...
end
```
