---
title: empty_if_block
---
# empty_if_block

This lint rule checks for empty blocks in `if`, `elseif`, and `else` statements.

## Why this is discouraged

Empty conditionals are indicative of incomplete or poorly written code and detract from readability.

## Options

This rule accepts the following configuration options:

- `comments_count` (boolean, default: `false`): When set to `true`, blocks that contain only comments are not considered empty and will not trigger a warning.

## Example violations

`empty_if_block` will warn on the following:

```luau
if condition then
end

if condition then
    -- Empty then block
elseif otherCondition then
    doSomething()
end

if condition then
    doSomething()
else
    -- Empty else block
end
```

## Configuration

To treat blocks with only comments as non-empty, configure the rule with `comments_count: true`:

```luau
-- This will not trigger a warning when comments_count is true
if condition then
    -- TODO: implement this later
end
```

### Sample `.config.luau` file
```luau
return {
	lute = {
        lint = { 
            rules = {
                empty_if_block = {
                    options = {
                        comments_count = true,
                    },
                },
            } 
        }
    },
}
```
