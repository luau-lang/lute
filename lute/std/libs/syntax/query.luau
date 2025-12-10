--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local tableext = require("@std/tableext")
local types = require("./types")
local visitor = require("./visitor")
local utils = require("./utils")

type node = types.AstNode

export type query<T = node> = {
	nodes: { T },
	filter: (self: query<T>, pred: (T) -> boolean) -> query<T>,
	replace: (self: query<T>, repl: (T) -> types.replacement?) -> types.replacements,
	map: <U>(self: query<T>, fn: (T) -> U?) -> query<U>, -- recursion violation reported
	foreach: (self: query<T>, callback: (T) -> ()) -> query<T>,
	findall: <U>(self: query<T>, fn: (node) -> U?) -> query<U>,
	flatmap: <U>(self: query<T>, fn: (T) -> { U }) -> query<U>,
	maptoarray: <U>(self: query<T>, fn: (T) -> U?) -> { U },
	exists: (self: query<T>, pred: ((T) -> boolean)?) -> boolean,
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

function queryLib.replace<T>(self: query<T>, repl: (T) -> types.replacement?): types.replacements
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

function queryLib.exists<T>(self: query<T>, predicate: ((T) -> boolean)?): boolean
	if not predicate then
		return #self.nodes > 0
	end

	for _, node in self.nodes do
		if predicate(node) then
			return true
		end
	end
	return false
end

local function newSelectVisitor<T>(nodes: { T }, fn: (node) -> T?): visitor.Visitor
	local function visit(n: node) -- LUAUFIX: type checker doesn't like assigning visit in the visitor fields with n: node
		local selected = fn(n)
		if selected ~= nil then
			table.insert(nodes, selected)
		end
		return true
	end

	local selectVisitor = visitor.create(visit)
	selectVisitor.visitStatBlockEnd = function(n) end
	selectVisitor.visitStatLocalDeclarationEnd = function(n) end
	selectVisitor.visitExpr = function(n)
		return true
	end
	selectVisitor.visitExprEnd = function(n) end
	selectVisitor.visitToken = function(n)
		if utils.isBaseToken(n) then
			-- only visit if it is a base token, so we don't double count
			return visit(n)
		end
		return true
	end

	return selectVisitor
end

function queryLib.findall<T, U>(self: query<T>, fn: (node) -> U?): query<U>
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

function queryLib.findallfromroot<T>(ast: types.ParseResult | node, fn: (node) -> T?): query<T>
	local nodes: { T } = {}

	local selectVisitor = newSelectVisitor(nodes, fn)

	local root: node = if ast.root ~= nil then ast.root else ast
	visitor.visit(root, selectVisitor)

	return {
		nodes = nodes,
		filter = queryLib.filter,
		replace = queryLib.replace,
		map = queryLib.map,
		foreach = queryLib.foreach,
		findall = queryLib.findall,
		flatmap = queryLib.flatmap,
		maptoarray = queryLib.maptoarray,
		exists = queryLib.exists,
	} -- LUAUFIX: queryLib.map has generics quantified at a different level than expected
end

return table.freeze(queryLib)
