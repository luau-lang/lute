# reassigned_parameter

This lint rule checks for reassignment of function parameters.

## Why this is discouraged

Sometimes, a parameter may be accidentally reassigned, especially if it is named fairly generically. This can lead to hard-to-spot bugs within the function.

## Example violations

`reassigned_parameter` will warn on the following:

```luau
local function _(x)
	x = 2
	x += 3
end
```