--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local luau = require("@std/luau")
local table = require("@std/table")
local visitor = require("@std/syntax/visitor")

type node = luau.AstNode

type delta =
	{ tag: "append", content: string }
	| { tag: "prepend", content: string }
	| { tag: "replace", content: string }
	| { tag: "remove" }

type replacement = string | node | { delta }
type replacements = { [node]: replacement }

export type query<T = node> = {
	nodes: { T },
	filter: (self: query<T>, pred: (T) -> boolean) -> query<T>,
	replace: (self: query<T>, repl: (T) -> replacement?) -> replacements,
	map: <U>(self: query<T>, fn: (T) -> U?) -> query<U>,
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

function queryLib.replace<T>(self: query<T>, repl: (T) -> replacement?): replacements
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
-- Because of the recursion constraint, we can't actually include this as a method of query right now
function queryLib.map<T, U>(self: query<T>, fn: (T) -> U?): query<U>
	local newNodes = {}
	for _, node in self.nodes do
		local mapped = fn(node)
		if mapped ~= nil then
			table.insert(newNodes, mapped)
		end
	end
	return { nodes = newNodes, filter = self.filter, replace = self.replace, map = self.map }
end

function queryLib.select<T>(ast: node, fn: (node) -> (T | { T })?): query<T>
	local nodes: { T } = {}

	local function visit(n: node) -- LUAUFIX: type checker doesn't like assigning visit in the visitor fields with n: node
		local selected = fn(n)
		if selected ~= nil then
			if selected.kind == nil then -- quick and dirty fix to check for array-like table
				table.extend(nodes, selected)
			else
				table.insert(nodes, selected)
			end
		end
		return true
	end

	local selectVisitor: visitor.Visitor = {
		visitBlock = visit,
		visitBlockEnd = function(n) end,
		visitIf = visit,
		visitWhile = visit,
		visitRepeat = visit,
		visitReturn = visit,
		visitLocalDeclaration = visit,
		visitLocalDeclarationEnd = function(n) end,
		visitFor = visit,
		visitForIn = visit,
		visitAssign = visit,
		visitCompoundAssign = visit,
		visitFunction = visit,
		visitLocalFunction = visit,
		visitTypeAlias = visit,
		visitStatTypeFunction = visit,

		visitExpression = function(n)
			return true
		end,
		visitExpressionEnd = function(n) end,
		visitLocalReference = visit,
		visitGlobal = visit,
		visitCall = visit,
		visitUnary = visit,
		visitBinary = visit,
		visitAnonymousFunction = visit,
		visitTableItem = visit,
		visitTable = visit,
		visitIndexName = visit,
		visitIndexExpr = visit,
		visitGroup = visit,
		visitInterpolatedString = visit,
		visitTypeAssertion = visit,
		visitIfExpression = visit,

		visitTypeReference = visit,
		visitTypeBoolean = visit,
		visitTypeString = visit,
		visitTypeTypeof = visit,
		visitTypeGroup = visit,
		visitTypeUnion = visit,
		visitTypeIntersection = visit,
		visitTypeArray = visit,
		visitTypeTable = visit,
		visitTypeFunction = visit,

		visitTypePackExplicit = visit,
		visitTypePackGeneric = visit,
		visitTypePackVariadic = visit,

		visitToken = function(n)
			return true
		end,
		visitNil = visit,
		visitString = visit,
		visitBoolean = visit,
		visitNumber = visit,
		visitLocal = visit,
		visitVarargs = visit,
	}

	local nodeKind: string = ast.kind
	if nodeKind == "stat" then
		local stat = ast :: luau.AstStat -- LUAUFIX: code too complex to typecheck
		if stat.tag == "block" then
			visitor.visitblock(stat, selectVisitor)
		else
			visitor.visitstatement(stat, selectVisitor)
		end
	elseif nodeKind == "expr" then
		visitor.visitexpression(ast :: luau.AstExpr, selectVisitor) -- LUAUFIX: code too complex to typecheck
	elseif nodeKind == "type" then
		visitor.visittype(ast :: luau.AstType, selectVisitor)
	elseif nodeKind == "typepack" then
		visitor.visittypepack(ast :: luau.AstTypePack, selectVisitor)
	elseif nodeKind == "token" then
		visitor.visittoken(ast :: luau.Token, selectVisitor)
	else
		error("Unsupported node kind: " .. tostring(nodeKind))
	end

	return { nodes = nodes, filter = queryLib.filter, replace = queryLib.replace, map = queryLib.map }
end

return table.freeze(queryLib)
