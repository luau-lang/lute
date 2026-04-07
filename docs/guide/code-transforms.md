---
order: 6
---

# Code Transformations
One of the coolest parts of Lute is that we've exposed many of the Luau internals programmatically. That means that things like types, require-resolution, the Luau AST(Abstract Syntax Tree), Luau bytecode, and so on are exposed with public facing apis that you can use. Of these features, one of the slickest things we've exposed is the ability to write automatic code transformations. Using Lute libraries, you can now programmatically  describe how to change Luau source code and `lute transform` will handle running these transformations for you. In the following sections, we'll walk through writing a simple code transformation which doubles any numbers in the source program (we assume some basic level of familiarity with what an [AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree) is). As in the previous library, we'll be creating a new directory, with one file - `transform.luau`. Make sure to run `lute setup` in this directory!

## Defining a code transformation

At the most basic level, a code transformation is a function that accepts a Context, as defined below, and returns a table of replacements. This table should map from `AstNode`'s in the original AST, to `string`'s they should be replaced with.

```luau
export type Context<Options = { [any]: any }> = {
	path: string,
	source: string,
	parseresult: syntax.ParseResult,
	options: Options,
}
```

Note that AST's are immutable - rather than mutating them in place, we specify the changes we would like to make using a table of replacements and `lute transform` applies them for us.

Lute provides two ways of writing transforms - a declarative, query based approach, and a visitor based approach. Since we recommend using the query based approach, we'll focus on that, and show how to write a visitor based approach at the end.

### Query Based AST transforms

In this section, we build up an example of a declarative 'query' based implementation which doubles any numbers found in the source program. We begin by selecting every AST node we're interested in - in this case, every number:

```luau
query.findAllFromRoot(astRoot, utils.isExprConstantNumber)
```

`findAllFromRoot` is a general entry point function into queries which filters all the nodes which match a certain condition. We specify this condition using a function which takes in an `AstNode` and returns either an `AstNode` or `nil`. In this case, `utils.isExprConstantNumber` has the following definition:

```luau
function utils.isExprConstantNumber(n: types.AstNode): types.AstExprConstantNumber?
	return if n.kind == "expr" and n.tag == "number" then n else nil
end
```

All `AstNode` objects have a `kind` field which denotes the broader category that the node falls into and a `tag` field which specifies the exact node type. So in this case, the `query.findAllFromRoot` call above will return all nodes which are number literals in our source AST.

Since we want to double all of these numbers, we extend our program to construct a table which maps all the number literals we've just collected to a string that each one should be replaced with:

```luau
local replacements = query.findAllFromRoot(astRoot, utils.isExprConstantNumber)
						:replace(function(numLiteral: AstExprConstantNumber)
							return `{ e.value * 2 }`
						end)
```

The manual work of collecting these replacements into a single table is handled by the original query's `:replace` method. All we need to do is pass a function which specifies how an AST node should be transformed into the string which will replace it.

To get this code into a format that `lute transform` can understand and run, we return the replacements from a function which takes the `Context` mentioned above, and create a file which returns that function. Here's what that looks like with the relevant imports included:

```luau
local codemod = require("@codemod/types")

local ast = require("@std/syntax")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

local function transformQuery(ctx: codemod.Context)
	return query.findAllFromRoot(ctx.parseResult, utils.isExprConstantNumber)
			:replace(function(numLiteral: ast.AstExprConstantNumber)
				return `{ e.value * 2 }`
			end)
end

return transformQuery
```

We now have a completed code transformation!

Next, we paste the above into `transform.luau`, and create another file, `subject.luau` containing just `local x = 2`.

If we now run:
```bash
lute transform.luau subject.luau
```
and open `subject.luau`, it should now contain `local x = 4` instead.

### Visitor Based AST tranforms

In this section, we build up another code transformation which doubles all numbers. This example will use the [AST visitor pattern](https://en.wikipedia.org/wiki/Visitor_pattern). 

We begin by instantiating a new visitor and a table to hold our replacements:

```luau
local myVisitor = visitor.create()
local replacements : { [ast.AstNode] : string } = {}
```

By default, visitors will "visit" every node of an AST. If we want to customize their behavior for certain AST node types, we do it by overloading the method for that node type:

```luau
local myVisitor = visitor.create()
local replacements : { [ast.AstNode] : string } = {}

function myVisitor.visitExprConstantNumber(numberLiteral: ast.AstExprConstantNumber)
	-- do something
	return false
end
```

Although it may seem innocuous, the value returned from a visitor method is quite important: it tells the visitor whether it should recurse into the subnodes of the node being visited (by default the visitor will recurse into every subnode). So the following would cause the visitor to skip the conditions and branch bodies of all if statements in the visited AST:

```luau
local anotherVisitor = visitor.create()

function anotherVisitor.visitStatIf(ifStatement: ast.AstStatIf)
	return false
end
```

Going back to our code transformation, we would like our visitor to add a new replacement to our collection of replacements each time it visits a new number literal. Additionally, in the Lute AST API, number literals have a single subnode: the token containing the number in the program text. However, for our purposes, we don't need the visitor to visit it, so we can skip it by returning `false`.

```luau
local myVisitor = visitor.create()
local replacements : { [ast.AstNode] : string } = {}

function myVisitor.visitExprConstantNumber(numberLiteral: ast.AstExprConstantNumber)
	replacements[numberLiteral] = `{ numberLiteral.value * 2 }`

	return false
end
```

Finally, we have to tell the visitor library to start visiting the AST using our visitor:

```luau
local myVisitor = visitorLib.create()
local replacements : { [ast.AstNode] : string } = {}

function myVisitor.visitExprConstantNumber(numberLiteral: ast.AstExprConstantNumber)
	replacements[numberLiteral] = `{ numberLiteral.value * 2 }`

	return false
end

visitorLib.visit(ast, myVisitor)
```

Here's what that looks like in the format `lute transform` expects:

```luau
local ast = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local function visitorTransformation(ctx)
	local myVisitor = visitorLib.create()
	local replacements : { [ast.AstNode] : string } = {}

	function myVisitor.visitExprConstantNumber(numberLiteral: ast.AstExprConstantNumber)
		replacements[numberLiteral] = `{ numberLiteral.value * 2 }`

		return false
	end

	visitorLib.visit(ctx.parseResult.root, myVisitor)

	return replacements
end

return transformVisitor
```
