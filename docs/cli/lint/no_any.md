---
title: no_any
---
# no_any

This lint rule checks for explicit uses of the `any` type annotation.

## Why this is discouraged

The `any` type disables type checking entirely for any value it touches, allowing unsafe operations without compiler errors.
This defeats the purpose of Luau's type system and can mask bugs that would otherwise be caught at analysis time.
Use `unknown` instead, which is type-safe: it requires you to narrow the type (e.g. via `typeof` checks) before performing operations on the value.
As an escape hatch, you may perform an unsound cast (`value :: T`), which both narrows the type and explicitly annotates the assumed runtime type contract.

## Example violations

`no_any` will warn on the following:

```luau
local x: any = getValue()
local function process(input: any): any
	return input.field
end
type Callback = (any) -> any
```

You should instead do:

```luau
local x: unknown = getValue()
local function process(input: unknown): unknown
	assert(typeof(input) == "table")
	return (input :: { field: unknown }).field
end
type Callback = (unknown) -> unknown
```
