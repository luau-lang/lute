# test_module

```luau
local test_module = require("@test/test_module")
```

## test_module.block_with_equals

Block comment with equals above function declaration

This tests nested bracket delimiters being recognized properly.

```luau
(name: string) -> string
```

## test_module.multiple_triple_dashes

Multiple triple-dash comments (---) above function declaration

Should capture both of these lines

Even if there are blank lines between them

```luau
(y: number) -> number
```

## test_module.property

Property declaration test: declare process.env as a map from string to string

```luau
{ [string]: string }
```

## test_module.triple_dash

Simple function with triple dashes comment that returns hello

```luau
(name: string) -> string
```
