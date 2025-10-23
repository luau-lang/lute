local luau = require("@std/luau")

type node = luau.AstNode

type delta =
	{ tag: "append", content: string }
	| { tag: "prepend", content: string }
	| { tag: "replace", content: string }
	| { tag: "remove" }

type replacement = string | node | { delta }
type replacements = { [node]: replacement }

type query<T = node> = {
	nodes: { T },
	filter: (self: query<T>, pred: (T) -> boolean) -> query<T>,
	replace: (self: query<T>, repl: (T) -> replacement) -> replacements,
}

-- select will return a query where its nodes are all the non-nil values returned by fn when called on each node of the original query
-- Because of the recursion constraint, we can't actually include this as a method of query right now
local function select<T, U>(q: query<T>, fn: (T) -> U?): query<U>
	error("Not implemented")
end

local function newQuery(ast: node): query<node>
	error("Not implemented")
end

local ast = (nil :: any) :: node

-- Example usage:
local utils = require("./utils")

local function curry(n: node): luau.AstExprCall?
	error("Not implemented")
end

local q = newQuery(ast)
local p = select(q, curry)
	:filter(function(call)
		local calledFunc = call.func
		return calledFunc.tag == "global" and calledFunc.name.text == "require"
	end)
	:filter(function(call)
		local firstArg = call.arguments[1].node
		return firstArg.tag == "indexname" and firstArg.index.text == "OldComponent"
	end)

local replacements = select(p, function(call: luau.AstExprCall)
	return call.arguments[1].node :: luau.AstExprIndexName
end):replace(function(node)
	return "NewComponent"
end)
