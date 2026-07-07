# reassigned_parameter

This lint rule checks for reassignment of function parameters.

## Why this is discouraged

A reassigned parameter may lead to hard-to-spot bugs.

## Example violations

`reassigned_parameter` will warn on the following:

```luau
local function _(x)
	x = 2
	x += 3
end
```