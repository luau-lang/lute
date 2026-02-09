# almost_swapped

This lint rule checks for instances of attempted swaps (i.e. `a = b; b = a`).

## Why this is discouraged

This will never result in the expected behavior.
In the example above, the value of `b` will be assigned to `a`.
Then, this same value gets assigned back to `b` (a no-op), resulting in both identifiers being bound the original value of `b`.
You should instead use Luau's multiple assigment syntax, which will swap as expected (i.e. `a, b = b, a`).

## Example violations

`almost_swapped` will warn on the following:

```luau
a = b
b = a
```

You should instead do:

```luau
a, b = b, a
```
