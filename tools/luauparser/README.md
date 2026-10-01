# luauparser

A **Luau parser written in pure Luau** — a dependency-free alternative to the
native `@lute/syntax` AST/CST APIs.

It parses Luau source text into a concrete syntax tree (CST) that is
**structurally identical** to the one produced by Lute's native parser, so you
can build linters, formatters, and codemods in plain Luau without the runtime
exposing any native AST APIs.

```luau
local luau = require("./tools/luauparser")

local result = luau.parse("local x = 1 + 2")
print(result.root.statements[1].tag) --> "local"

for _, node in luau.findAll(result.root, luau.is("expr", "binary")) do
	print(node.operator.text) --> "+"
end
```

## Why

The native parser hands back a CST through C++ bindings (`@lute/syntax/parser`).
That couples tooling to the runtime's AST surface. This library reproduces the
exact same CST in Luau, so the AST APIs don't need to be exposed at all —
everything downstream (lints like `examples/lints/`) keeps working against an
identical tree.

## Usage

Require the folder (it has an `init.luau` entry point):

```luau
local luau = require("<path>/tools/luauparser")
```

### API

| Function | Description |
| --- | --- |
| `luau.parse(source)` | Parse a chunk → `{ root, eof, lines, lineOffsets }` (`root` is a `block` node). |
| `luau.parseBlock(source)` | Parse a chunk and return just the root `block` node. |
| `luau.parseExpr(source)` | Parse a single expression → a CST expression node. |
| `luau.walk(root, visit)` | Depth-first walk; `visit(node)` per node. Return `false` to skip children. |
| `luau.findAll(root, pred)` | All nodes matching `pred(node)`, in document order. |
| `luau.find(root, pred)` | First node matching `pred(node)`, or `nil`. |
| `luau.is(kind, tag?)` | Build a predicate, e.g. `luau.is("expr", "binary")` or `luau.is("stat")`. |

### The CST

Every node carries:

- `kind` — `"stat"`, `"expr"`, `"type"`, `"typepack"`, `"local"`, `"attribute"`, or `"token"`.
- `tag` — a discriminator within a kind (e.g. `kind = "expr"`, `tag = "binary"`).
- `location` — a 1-based span `{ beginLine, beginColumn, endLine, endColumn }`.

Keyword/punctuation tokens are `{ kind = "token", text, location, leadingTrivia, trailingTrivia }`,
and whitespace/comments are preserved as trivia on the surrounding tokens — so
the tree round-trips to the original source. The node shapes match
`@lute/syntax/cst` exactly; see that file for the full type definitions.

## Example

A tiny linter that flags divide-by-zero, built entirely on this parser:

```sh
lute run tools/luauparser/divide_by_zero_example.luau
```

```
2:9  warning  dividing by zero with '/' always yields NaN; consider 'math.nan'
   | 	return 3.14 * r / 0
   |         ^
```

See [`divide_by_zero_example.luau`](./divide_by_zero_example.luau).

## Correctness

The parser is verified against the native reference parser: a harness parses the
same source with both and compares the serialized CSTs for exact equality.

```sh
# built-in micro-cases:
lute run tools/luauparser/harness/compare.luau
# specific files, or a newline-separated list via @file:
lute run tools/luauparser/harness/compare.luau path/to/file.luau
```

It matches the native CST on every non-vendored `.luau` file in this repo (500+
files) plus the built-in cases.

## Layout

```
init.luau            public API (parse / walk / findAll / find / is)
divide_by_zero_example.luau   runnable demo linter
src/
  lexer.luau         tokenizer (port of Luau's Lexer.cpp)
  parser.luau        recursive-descent parser + CST builder
  builder.luau       token / trivia / span reconstruction
harness/
  compare.luau       diff against the native parser
  serialize.luau     canonical CST serializer
```

## Limitations

- Targets **valid** Luau. Error-recovery output for malformed input is not
  guaranteed to match the native parser's error shapes.
- The `@[attr attr]` attribute-list form and `declare` syntax are not
  implemented (neither is used in this repo).
