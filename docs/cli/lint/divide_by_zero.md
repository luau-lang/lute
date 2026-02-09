---
title: divide_by_zero
---
# divide_by_zero

This lint rule checks for instances of divison, floor division, or taking the remainder with respect to the literal value 0.

## Why this is discouraged

Division and floor division by 0 will generally give `inf` or `-inf` (unless the dividend is 0).
The direct use of `math.huge` or `-math.huge` instead is encouraged.
Taking remainder with respect to 0 (i.e. `3 % 0`) will give `NaN`.
We instead encourage the use of `0 / 0` until such time as a `NaN` constant is added to `math`.

## Example violations

`divide_by_zero` will warn on the following:

```luau
local x = 3 / 0
local y = -4 // 0
local z = 24 % 0
```

You should instead do:

```luau
local x = math.huge
local y = -math.huge
local z = 0 / 0
```
