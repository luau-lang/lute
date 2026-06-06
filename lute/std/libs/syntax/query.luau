--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau CST nodes

local tableext = require("@std/tableext")
local types = require("./types")
local visitor = require("./visitor")

type Node = types.CstNode

--- A collection of CST nodes that supports chained filtering, mapping, and replacement operations.
export type Query<T = Node> = {
	nodes: { T },
	filter: (self: Query<T>, pred: (T) -> boolean) -> Query<T>,
	replace: (self: Query<T>, repl: (T) -> types.Replacement?) -> types.Replacements,
	map: <U>(self: Query<T>, fn: (T) -> U?) -> Query<U>, -- recursion violation reported
	forEach: (self: Query<T>, callback: (T) -> ()) -> Query<T>,
	findAll: <U>(self: Query<T>, fn: (Node) -> U?) -> Query<U>,
	flatMap: <U>(self: Query<T>, fn: (T) -> { U }) -> Query<U>,
	mapToArray: <U>(self: Query<T>, fn: (T) -> U?) -> { U },
}

local queryLib = {}

--- Retains only the nodes for which `pred` returns `true`. Mutates and returns the query.
function queryLib.filter<T>(self: Query<T>, pred: (T) -> boolean): Query<T>
	local newNodes = {}
	for _, node in self.nodes do
		if pred(node) then
			table.insert(newNodes, node)
		end
	end
	self.nodes = newNodes
	return self
end

--- Calls `repl` on each node and collects the non-nil results into a `Replacements` table for use with the printer.
function queryLib.replace<T>(self: Query<T>, repl: (T) -> types.Replacement?): types.Replacements
	local replacements = {}
	for _, node in self.nodes do
		local r = repl(node)
		if r ~= nil then
			replacements[node] = r
		end
	end
	return replacements
end

--- Replaces the query's nodes with the non-nil values returned by `fn` for each node. Mutates and returns the query.
function queryLib.map<T, U>(self: Query<T>, fn: (T) -> U?): Query<U>
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

--- Calls `callback` on each node. Returns the query unchanged for chaining.
function queryLib.forEach<T>(self: Query<T>, callback: (T) -> ()): Query<T>
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

--- Recursively visits every descendant of each node in the query and collects those for which `fn` returns a non-nil value. Mutates and returns the query.
function queryLib.findAll<T, U>(self: Query<T>, fn: (Node) -> U?): Query<U>
	local selectedNodes: { U } = {}

	local selectVisitor = newSelectVisitor(selectedNodes, fn)

	for _, node in self.nodes do
		visitor.visit(node, selectVisitor)
	end

	self.nodes = selectedNodes

	return self
end

--- Replaces each node with the array of values returned by `fn`, flattening one level. Mutates and returns the query.
function queryLib.flatMap<T, U>(self: Query<T>, fn: (T) -> { U }): Query<U>
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

--- Returns a plain array of the non-nil values produced by calling `fn` on each node. Does not mutate the query.
function queryLib.mapToArray<T, U>(self: Query<T>, fn: (T) -> U?): { U }
	local result = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if mapped ~= nil then
			table.insert(result, mapped)
		end
	end
	return result
end

--- Creates a new `Query` by visiting every node in `cst` and collecting those for which `fn` returns a non-nil value.
function queryLib.findAllFromRoot<T>(cst: types.CstParseResult | Node, fn: (Node) -> T?): Query<T>
	local nodes: { T } = {}

	local selectVisitor = newSelectVisitor(nodes, fn)

	local root: Node = if (cst :: any).root ~= nil then (cst :: any).root else cst :: any -- LUAUFIX: Replace any cast with cast to node once code too complex no longer emitted
	visitor.visit(root, selectVisitor)

	return {
		nodes = nodes,
		filter = queryLib.filter,
		replace = queryLib.replace,
		map = queryLib.map :: any, -- LUAUFIX: Remove any cast once recursion restriction is loosened
		forEach = queryLib.forEach,
		findAll = queryLib.findAll :: any, -- LUAUFIX: Remove any cast once recursion restriction is loosened
		flatMap = queryLib.flatMap,
		mapToArray = queryLib.mapToArray :: any, -- Any cast because mapToArray has generics quantified at a different level than the query type expects
	}
end

return table.freeze(queryLib)
