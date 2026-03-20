--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local tableext = require("@std/tableext")
local types = require("./types")
local visitor = require("./visitor")

type Node = types.AstNode

export type query<T = Node> = {
	nodes: { T },
	filter: (self: query<T>, pred: (T) -> boolean) -> query<T>,
	replace: (self: query<T>, repl: (T) -> types.Replacement?) -> types.Replacements,
	map: <U>(self: query<T>, fn: (T) -> U?) -> query<U>, -- recursion violation reported
	foreach: (self: query<T>, callback: (T) -> ()) -> query<T>,
	findall: <U>(self: query<T>, fn: (Node) -> U?) -> query<U>,
	flatmap: <U>(self: query<T>, fn: (T) -> { U }) -> query<U>,
	maptoarray: <U>(self: query<T>, fn: (T) -> U?) -> { U },
}

local queryLib = {}

function queryLib.filter<T>(self: query<T>, pred: (T) -> boolean): query<T>
	local newNodes = {}
	for _, node in self.nodes do
		if pred(node) then
			table.insert(newNodes, node)
		end
	end
	self.nodes = newNodes
	return self
end

function queryLib.replace<T>(self: query<T>, repl: (T) -> types.Replacement?): types.Replacements
	local replacements = {}
	for _, node in self.nodes do
		local r = repl(node)
		if r ~= nil then
			replacements[node] = r :: any -- LUAUFIX: remove any cast once code too complex no longer emitted
		end
	end
	return replacements
end

-- map will return a query where its nodes are all the non-nil values returned by fn when called on each node of the original query
function queryLib.map<T, U>(self: query<T>, fn: (T) -> U?): query<U>
	local newNodes = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if mapped ~= nil then
			table.insert(newNodes, mapped)
		end
	end
	self.nodes = newNodes
	return self
end

function queryLib.foreach<T>(self: query<T>, callback: (T) -> ()): query<T>
	for _, node in self.nodes do
		callback(node)
	end
	return self
end

local function newSelectVisitor<T>(nodes: { T }, fn: (Node) -> T?): visitor.Visitor
	local function visit(n: Node)
		local selected = fn(n)
		if selected ~= nil then
			table.insert(nodes, selected)
		end
		return true
	end

	local selectVisitor = visitor.create(visit)
	selectVisitor.visitStatBlockEnd = function(_) end
	selectVisitor.visitStatLocalDeclarationEnd = function(_) end
	selectVisitor.visitExpr = function(_)
		return true
	end
	selectVisitor.visitExprEnd = function(_) end

	return selectVisitor
end

function queryLib.findall<T, U>(self: query<T>, fn: (Node) -> U?): query<U>
	local selectedNodes: { U } = {}

	local selectVisitor = newSelectVisitor(selectedNodes, fn)

	for _, node in self.nodes do
		visitor.visit(node, selectVisitor)
	end

	self.nodes = selectedNodes

	return self
end

function queryLib.flatmap<T, U>(self: query<T>, fn: (T) -> { U }): query<U>
	local newNodes: { U } = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if #mapped > 0 then
			tableext.extend(newNodes, mapped)
		end
	end
	self.nodes = newNodes
	return self
end

function queryLib.maptoarray<T, U>(self: query<T>, fn: (T) -> U?): { U }
	local result = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if mapped ~= nil then
			table.insert(result, mapped)
		end
	end
	return result
end

function queryLib.findallfromroot<T>(ast: types.ParseResult | Node, fn: (Node) -> T?): query<T>
	local nodes: { T } = {}

	local selectVisitor = newSelectVisitor(nodes, fn)

	local root: Node = if (ast :: any).root ~= nil then (ast :: any).root else ast :: any -- LUAUFIX: Replace any cast with cast to Node once code too complex no longer emitted
	visitor.visit(root, selectVisitor)

	return {
		nodes = nodes,
		filter = queryLib.filter,
		replace = queryLib.replace :: any, -- LUAUFIX: Remove any cast once code too complex no longer emitted
		map = queryLib.map :: any, -- LUAUFIX: Remove any cast once recursion restriction is loosened
		foreach = queryLib.foreach,
		findall = queryLib.findall :: any, -- LUAUFIX: Remove any cast once recursion restriction is loosened
		flatmap = queryLib.flatmap,
		maptoarray = queryLib.maptoarray :: any, -- Any cast because maptoarray has generics quantified at a different level than the query type expects
	}
end

return table.freeze(queryLib)
