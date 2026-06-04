---
order: 6
---

# Code Transformations
One of the coolest parts of Lute is that we've exposed many parts of the Luau programming language like types, require-resolution, the Luau concrete syntax tree (CST), and Luau bytecode.
We've used these APIs to build `lute transform`: A tool to write automated and deterministic code transformations.
This means that you can now use Lute libraries to programmatically describe how to change Luau source code and apply these changes using `lute transform`. 
In the following sections, we'll walk through writing a simple code transformation which doubles any numbers in the source program (we assume some basic level of familiarity with what an [AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree) is; a CST is just an AST with some extra information).
As in the previous library, we'll be creating a new directory, with one file - `transform.luau`. Make sure to run `lute setup` in this directory!

## Defining a code transformation

At the most basic level, a code transformation is a function that accepts a Context, as defined below, and returns a table of replacements. This table should map from `CstNode`'s in the original CST, to `string`'s they should be replaced with.

```luau
export type Context<Options = { [any]: any }> = {
	path: string,
	source: string,
	parseresult: syntax.ParseResult,
	options: Options,
}
```

Note that CST's are immutable - rather than mutating them in place, we specify the changes we would like to make using a table of replacements and `lute transform` applies them for us.

:::info
The returned table of replacements should have type `{ [CstNode] : string }`, ie map `CstNode`'s to the strings we would like to replace them with.
For now, we only support string replacements since manually constructing `CstNode` tables is more error prone. 
If you still want to construct replacement `CstNode`'s by hand, you can use the `@std/printer` library to serialize them before inserting them into your replacement map.
:::

Lute provides two ways of writing transforms: A declarative, query based approach, and a visitor based approach. 
Most transformations can be written with the query approach. We'll start with that and discuss a visitor approach later.

### Query Based CST transforms

In this section, we build up an example of a query based implementation which doubles any numbers found in the source program.
We begin by selecting every CST node we're interested in - in this case, every number:

```luau
query.findAllFromRoot(cstRoot, utils.isExprConstantNumber)
```

`findAllFromRoot` is a general entry point function into queries which filters all the nodes which match a certain condition. We specify this condition using a function which takes in an `CstNode` and returns either an `CstNode` or `nil`. In this case, `utils.isExprConstantNumber` has the following definition:

```luau
function utils.isExprConstantNumber(n: types.CstNode): types.CstExprConstantNumber?
	return if n.kind == "expr" and n.tag == "number" then n else nil
end
```

All `CstNode` objects have a `kind` field which denotes the broader category that the node falls into and a `tag` field which specifies the exact node type. So in this case, the `query.findAllFromRoot` call above will return all nodes which are number literals in our source CST.

Since we want to double all of these numbers, we extend our program to construct a table which maps all the number literals we've just collected to a string that each one should be replaced with:

```luau
local replacements = query.findAllFromRoot(cstRoot, utils.isExprConstantNumber)
						:replace(function(numLiteral: CstExprConstantNumber)
							return `{ numLiteral.value * 2 }`
						end)
```

The manual work of collecting these replacements into a single table is handled by the original query's `:replace` method. All we need to do is pass a function which specifies how an CST node should be transformed into the string which will replace it.

To get this code into a format that `lute transform` can understand and run, we return the replacements from a function which takes the `Context` mentioned above, and create a file which returns that function. Here's what that looks like with the relevant imports included:

```luau
local cst = require("@std/syntax")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

local function transformQuery(ctx)
	return query.findAllFromRoot(ctx.parseresult, utils.isExprConstantNumber)
			:replace(function(numLiteral: cst.CstExprConstantNumber)
				return `{ numLiteral.value * 2 }`
			end)
end

return transformQuery
```

We now have a completed code transformation!

Next, we paste the above into `transform.luau`, and create another file, `subject.luau` containing just `local x = 2`.

If we now run:
```bash
lute transform transform.luau subject.luau
```
and open `subject.luau`, it should now contain `local x = 4` instead.

### Visitor Based CST tranforms

In this section, we build up another code transformation which doubles all numbers. This example will use the [CST visitor pattern](https://en.wikipedia.org/wiki/Visitor_pattern). 

We begin by instantiating a new visitor and a table to hold our replacements:

```luau
local myVisitor = visitor.create()
local replacements : { [cst.CstNode] : string } = {}
```

By default, visitors will "visit" every node of an CST. If we want to customize their behavior for certain CST node types, we do it by overloading the method for that node type:

```luau
local myVisitor = visitor.create()
local replacements : { [cst.CstNode] : string } = {}

function myVisitor.visitExprConstantNumber(numberLiteral: cst.CstExprConstantNumber)
	-- do something
	return false
end
```

Although it may seem innocuous, the value returned from a visitor method is quite important: it tells the visitor whether it should recurse into the subnodes of the node being visited (by default the visitor will recurse into every subnode). So the following would cause the visitor to skip the conditions and branch bodies of all if statements in the visited CST:

```luau
local anotherVisitor = visitor.create()

function anotherVisitor.visitStatIf(ifStatement: cst.CstStatIf)
	return false
end
```

Going back to our code transformation, we would like our visitor to add a new replacement to our collection of replacements each time it visits a new number literal. Additionally, in the Lute CST API, number literals have a single subnode: the token containing the number in the program text. However, for our purposes, we don't need the visitor to visit it, so we can skip it by returning `false`.

```luau
local myVisitor = visitor.create()
local replacements : { [cst.CstNode] : string } = {}

function myVisitor.visitExprConstantNumber(numberLiteral: cst.CstExprConstantNumber)
	replacements[numberLiteral] = `{ numberLiteral.value * 2 }`

	return false
end
```

Finally, we have to tell the visitor library to start visiting the CST using our visitor:

```luau
local myVisitor = visitorLib.create()
local replacements : { [cst.CstNode] : string } = {}

function myVisitor.visitExprConstantNumber(numberLiteral: cst.CstExprConstantNumber)
	replacements[numberLiteral] = `{ numberLiteral.value * 2 }`

	return false
end

visitorLib.visit(cst, myVisitor)
```

Here's what that looks like in the format `lute transform` expects:

```luau
local cst = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local function visitorTransformation(ctx)
	local myVisitor = visitorLib.create()
	local replacements : { [cst.CstNode] : string } = {}

	function myVisitor.visitExprConstantNumber(numberLiteral:cst.CstExprConstantNumber)
		replacements[numberLiteral] = `{ numberLiteral.value * 2 }`

		return false
	end

	visitorLib.visit(ctx.parseresult.root, myVisitor)

	return replacements
end

return visitorTransformation
```
