--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local tableext = require("@std/tableext")
local types = require("./types")
local visitor = require("./visitor")

type Node = types.AstNode

export type Query<T = Node> = {
	nodes: { T },
	filter: (self: Query<T>, pred: (T) -> boolean) -> Query<T>,
	replace: (self: Query<T>, repl: (T) -> string?) -> types.Replacements,
	map: <U>(self: Query<T>, fn: (T) -> U?) -> Query<U>, -- recursion violation reported
	forEach: (self: Query<T>, callback: (T) -> ()) -> Query<T>,
	findAll: <U>(self: Query<T>, fn: (Node) -> U?) -> Query<U>,
	flatMap: <U>(self: Query<T>, fn: (T) -> { U }) -> Query<U>,
	mapToArray: <U>(self: Query<T>, fn: (T) -> U?) -> { U },
}

local queryLib = {}

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

function queryLib.replace<T>(self: Query<T>, repl: (T) -> string?): types.Replacements
	local replacements = {}
	for _, node in self.nodes do
		local r = repl(node)
		if r ~= nil then
			replacements[node] = r
		end
	end
	return replacements
end

-- map will return a query where its nodes are all the non-nil values returned by fn when called on each node of the original query
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

function queryLib.findAll<T, U>(self: Query<T>, fn: (Node) -> U?): Query<U>
	local selectedNodes: { U } = {}

	local selectVisitor = newSelectVisitor(selectedNodes, fn)

	for _, node in self.nodes do
		visitor.visit(node, selectVisitor)
	end

	self.nodes = selectedNodes

	return self
end

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

function queryLib.findAllFromRoot<T>(ast: types.ParseResult | Node, fn: (Node) -> T?): Query<T>
	local nodes: { T } = {}

	local selectVisitor = newSelectVisitor(nodes, fn)

	local root: Node = if (ast :: any).root ~= nil then (ast :: any).root else ast :: any -- LUAUFIX: Replace any cast with cast to node once code too complex no longer emitted
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
