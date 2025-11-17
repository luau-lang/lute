# test_module

```luau
local test_module = require("@test/test_module")
```

## test_module.block

Block comment above function declaration

It can span multiple lines and include more detail.

```luau
(a: string, b: string) -> string
```

## test_module.block_with_equals

Block comment with equals above function declaration

This tests nested bracket delimiters being recognized properly.

```luau
(name: string) -> string
```

## test_module.multiple_single_lines

single line comment (--) directly above function declaration

should capture both of these single-line comments as a comment for the multiple_single_line_comment function

```luau
(x: number) -> number
```

## test_module.multiple_triple_dashes

multiple triple-dash comments (---) above function declaration

should capture both of these lines

```luau
(y: number) -> number
```

## test_module.property

property declaration test: declare process.env as a map from string to string

```luau
{ [string]: string }
```

## test_module.single_line

simple add function with two dashes comment that returns the sum of two numbers

```luau
(a: number, b: number) -> number
```

## test_module.triple_dash

simple hello function with triple dashes comment

```luau
(name: string) -> string
```
