---
title: global_function_in_scope
---
# global_function_in_scope

This lint rule warns when a non-local `function` declaration appears inside a nested scope (e.g. inside an `if`, `for`, `while`, `do`, or another function body) rather than at the top level of the file.

## Why this is discouraged

A `function foo() end` declaration without the `local` keyword inside a nested scope implicitly creates or assigns to a global variable. This is almost always unintentional and can lead to:

- Accidental global pollution, where the function leaks into the global environment.
- Confusing behavior, because the assignment only happens when the enclosing scope executes.
- Harder-to-debug shadowing issues when another scope references the same global name.

If the function is only needed locally, use `local function` instead. If it genuinely needs to be a top-level declaration, move it out of the nested scope.

## Example violations

`global_function_in_scope` will warn on the following:

```luau
if true then
    function foo()
    end
end

local function outer()
    function inner()
    end
end
```

You should instead do:

```luau
if true then
    local function foo()
    end
end

local function outer()
    local function inner()
    end
end
```
