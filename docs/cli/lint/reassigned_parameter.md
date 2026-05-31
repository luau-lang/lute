# reassigned_parameter

This lint rule checks for reassignment of function parameters.

## Why this is discouraged

Normally, variables can be declared as `const` to avoid accidental reassignment. However, this is unavailable for function parameters, which can make it harder to understand the flow of the function if there are accidental reassignments.

## Example violations

`reassigned_parameter` will warn on the following:

```luau
local function _(x)
	x = 2
	x += 3
end
```