---
order: 6
---

# Code Transforms
One of the coolest parts of Lute is that we've exposed many of the Luau internals programmatically. That means that things like types, require-resolution, the Luau AST(Abstract Syntax Tree), Luau bytecode and so on are exposed with public facing apis that you can use. Of these features, one of the slickest things we've exposed
is the ability to write automatic code transformations. Using Lute libraries, you can now programmatically  describe how to change Luau source code and `lute transform` will handle running these transformations for you. In this chapter, we'll walk through writing a simple code transform. As in the previous library, we'll be creating a new directory, with one file - `transform.luau`. Make sure to run `lute setup` in this directory!

## Defining a code transform

A code transform is any function that takes a Context, defined below, and returns a table of replacements. This table should map from `AstNode`'s in the source AST, to their replacements, which can be
1) a `string`, representing some text that should be parsed and turned into some AstNode, or
2) an `AstNode` that you have constructed.

```luau
export type Context<Options = { [any]: any }> = {
	path: string,
	source: string,
	parseresult: syntax.ParseResult,
	options: Options,
}
```

Note that AST's are immutable - you describe the changes you would like done to them, and the `transform` subcommand for lute figures out how to apply them. You don't mutate them in place. A transformer is a module that returns one function, with the type `Context -> {[ast.AstNode]: ast.AstNode | string} `, where the return type denotes a list of replacements to make.

Lute provides two ways of writing transforms - a visitor based approach, and a declarative, query based approach. We'll show you how to implement both of these.

To invoke a code transform, you can run:
```bash
lute transform path/to/transformer path/to/file/to/be/transformed
```
and Lute will apply the code transformation for you.

### Visitor Based AST tranforms

Here's an example of a simple visitor that doubles every constant number and prefixes every string literal with "AUDIT: ". Create a file for this called `transform.luau`. 

```luau
local ast = require("@std/syntax")
local visitor = require("@std/syntax/visitor")

local function transformVisitor(ctx)
	local fancy = visitor.create()
	local replacements : {[ast.AstNode]: ast.AstNode | string} = {}
	fancy.visitExprConstantNumber = function(e : ast.AstExprConstantNumber)
		replacements[e] = `{e.value * 2}`
		return true
	end

	fancy.visitExprConstantString = function(e : ast.AstExprConstantString)
		if e.quotestyle == "double" then
			replacements[e] = `"AUDIT: {e.text}"`
		end
		return true
	end

	visitor.visit(ctx.parseresult.root, fancy)
	return replacements
			
end

return transformVisitor
```

Create a file for the target - `target.luau`:

```luau
local x = "This is some string we have to edit"

local y = 2

function foo(x)
	return "Special values!", 3 * y
end

foo("Another constant string!")
```

You can run this transform with `lute transform path/to/transform.luau path/to/target.luau`, and see that the file becomes:

```luau
local x = "AUDIT: This is some string we have to edit"

local y = 4

function foo(x)
	return "AUDIT: Special values!", 6 * y
end

foo("AUDIT: Another constant string!")
```

### Query Based AST transforms

In contrast to the above transform written as a visitor, you can see an example of a declarative 'query' based implementation. We describe the set of nodes that we're interested in, and then at the very end, describe the transform that we want to apply to that set of nodes.

```luau
local query = require("@std/syntax/query")
local ast = require("@std/syntax")
local utils = require("@std/syntax/utils")

local function transformQuery(ctx)
	return query
		.findallfromroot(ctx.parseresult.root, function(n)
			return utils.isExprConstantNumber(n) or utils.isExprConstantString(n)
		end)
		:replace(function(e)
			if e.tag == "string" and e.quotestyle == "double" then
				return `AUDIT: {e.text}`
			elseif e.tag == "number" then
				return `{ e.value * 2 }`
			end
		end)
end

return transformQuery
```
