--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local luau = require("@std/luau")
local visitor = require("@self/visitor")

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

local function filter<T>(self: query<T>, pred: (T) -> boolean): query<T>
	local newNodes = {}
	for _, node in self.nodes do
		if pred(node) then
			table.insert(newNodes, node)
		end
	end
	self.nodes = newNodes
	return self
end

local function replace<T>(self: query<T>, repl: (T) -> replacement): replacements
	local replacements = {}
	for _, node in self.nodes do
		replacements[node] = repl(node)
	end
	return replacements
end

-- map will return a query where its nodes are all the non-nil values returned by fn when called on each node of the original query
-- Because of the recursion constraint, we can't actually include this as a method of query right now
local function map<T, U>(q: query<T>, fn: (T) -> U?): query<U>
	local newNodes = {}
	for _, node in q.nodes do
		local mapped = fn(node)
		if mapped ~= nil then
			table.insert(newNodes, mapped)
		end
	end
	return { nodes = newNodes, filter = filter, replace = replace }
end

local function select<T>(ast: node, fn: (node) -> T?): query<T>
	local nodes: { T } = {}

	local function visit(n: node)
		local selected = fn(n)
		if selected ~= nil then
			table.insert(nodes, selected)
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

		visitExpression = visit,
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

		visitToken = visit,
		visitNil = visit,
		visitString = visit,
		visitBoolean = visit,
		visitNumber = visit,
		visitLocal = visit,
		visitVarargs = visit,
	}

	-- todo call the visitor
	local nodeKind: string = (ast :: any).kind
	if nodeKind == "stat" then
		if (ast :: any).tag == "block" then
			visitor.visitBlock(ast :: luau.AstStatBlock, selectVisitor)
		else
			visitor.visitStatement((ast :: any) :: luau.AstStat, selectVisitor)
		end
	elseif nodeKind == "expr" then
		visitor.visitExpression((ast :: any) :: luau.AstExpr, selectVisitor)
	elseif nodeKind == "type" then
		visitor.visitType((ast :: any) :: luau.AstType, selectVisitor)
	elseif nodeKind == "typepack" then
		visitor.visitTypePack((ast :: any) :: luau.AstTypePack, selectVisitor)
	elseif nodeKind == "token" then
		visitor.visitToken((ast :: any) :: luau.Token<any>, selectVisitor)
	else
		error("Unsupported node kind: " .. tostring(nodeKind))
	end

	return { nodes = nodes, filter = filter, replace = replace }
end

return table.freeze({
	select = select,
	map = map,
})
