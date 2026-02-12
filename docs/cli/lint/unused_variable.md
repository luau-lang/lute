# unused_variable

This lint rule checks for instances of unused locals.
Unlike Luau's built-in linter, this also flags instances of unused function parameters and loop variables.
To silence instances of deliberately unused variables, lint warnings can be silenced by prefixing the variable name with `_`.

## Why this is discouraged

Unused variables can result in less readable code in the best case, and worse performance in the worst case.

## Example violations

`constant_table_comparison` will warn on the following:

```luau
local function _(x)
	return nil
end
```

You should instead consider:

```luau
local function _()
    return nil
end
```

Or simply silence the warning:
```luau
local function _(_x)
	return nil
end
```