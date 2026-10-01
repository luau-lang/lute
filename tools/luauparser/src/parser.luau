--!nocheck
-- Pure-Luau port of Luau's recursive-descent parser (Ast/src/Parser.cpp) fused
-- with the CST-building visitor (lute/syntax/src/parser.cpp). Produces a CST
-- structurally identical to the native `@lute/syntax/parser`.
--
-- Strategy: during parsing we build CST node tables directly and create token
-- "placeholders" (`{ _pos, text }`) wherever the native serializer would emit a
-- token. Node locations/spans are computed inline. After parsing, placeholders
-- are sorted by source position (= the serializer's emission order for valid
-- programs) and filled with reconstructed leading/trailing trivia by `builder`.

local lexermod = require("./lexer")
local buildermod = require("./builder")

local T = lexermod.T

type Position = lexermod.Position

local Parser = {}
Parser.__index = Parser

-- Binary operator metadata: text (== Luau toString) + {left, right} priority.
local BINARY = {
	["+"] = { text = "+", left = 6, right = 6 },
	["-"] = { text = "-", left = 6, right = 6 },
	["*"] = { text = "*", left = 7, right = 7 },
	["/"] = { text = "/", left = 7, right = 7 },
	["//"] = { text = "//", left = 7, right = 7 },
	["%"] = { text = "%", left = 7, right = 7 },
	["^"] = { text = "^", left = 10, right = 9 },
	[".."] = { text = "..", left = 5, right = 4 },
	["~="] = { text = "~=", left = 3, right = 3 },
	["=="] = { text = "==", left = 3, right = 3 },
	["<"] = { text = "<", left = 3, right = 3 },
	["<="] = { text = "<=", left = 3, right = 3 },
	[">"] = { text = ">", left = 3, right = 3 },
	[">="] = { text = ">=", left = 3, right = 3 },
	["and"] = { text = "and", left = 2, right = 2 },
	["or"] = { text = "or", left = 1, right = 1 },
}

-- Map lexeme type -> binary op key.
local function binaryOpKey(ty: number): string?
	if ty == 43 then
		return "+"
	elseif ty == 45 then
		return "-"
	elseif ty == 42 then
		return "*"
	elseif ty == 47 then
		return "/"
	elseif ty == T.FloorDiv then
		return "//"
	elseif ty == 37 then
		return "%"
	elseif ty == 94 then
		return "^"
	elseif ty == T.Dot2 then
		return ".."
	elseif ty == T.NotEqual then
		return "~="
	elseif ty == T.Equal then
		return "=="
	elseif ty == 60 then
		return "<"
	elseif ty == T.LessEqual then
		return "<="
	elseif ty == 62 then
		return ">"
	elseif ty == T.GreaterEqual then
		return ">="
	elseif ty == T.ReservedAnd then
		return "and"
	elseif ty == T.ReservedOr then
		return "or"
	end
	return nil
end

local function unaryOpText(ty: number): string?
	if ty == T.ReservedNot then
		return "not"
	elseif ty == 45 then
		return "-"
	elseif ty == 35 then
		return "#"
	end
	return nil
end

local function compoundOpText(ty: number): string?
	if ty == T.AddAssign then
		return "+"
	elseif ty == T.SubAssign then
		return "-"
	elseif ty == T.MulAssign then
		return "*"
	elseif ty == T.DivAssign then
		return "/"
	elseif ty == T.FloorDivAssign then
		return "//"
	elseif ty == T.ModAssign then
		return "%"
	elseif ty == T.PowAssign then
		return "^"
	elseif ty == T.ConcatAssign then
		return ".."
	end
	return nil
end

-- Position helpers (0-based).
local function copyPos(p: Position): Position
	return { line = p.line, column = p.column }
end

local function posLess(a: Position, b: Position): boolean
	if a.line == b.line then
		return a.column < b.column
	end
	return a.line < b.line
end

-- Build a span (1-based CST location) from two 0-based positions.
local function spanOf(b: Position, e: Position): any
	return buildermod.span({ begin = b, endPos = e })
end

local function new(source: string)
	local self = setmetatable({
		source = source,
		lineOffsets = buildermod.computeLineOffsets(source),
		lexer = lexermod.new(source),
		comments = {}, -- { { kind, location } }
		tokens = {}, -- token placeholders
		localStack = {},
		localMap = {}, -- name -> local (CstLocal-ish) current binding
		cstLocals = {}, -- identity map astLocal -> cst table (we use the local table itself)
		functionVarargStack = { true },
	}, Parser)
	self.lexer:setSkipComments(true)
	self:nextLexeme()
	return self
end

function Parser.current(self): lexermod.Lexeme
	return self.lexer.lexeme
end

function Parser.lookahead(self): lexermod.Lexeme
	return self.lexer:lookahead()
end

function Parser.nextLexeme(self)
	local lx = self.lexer
	local lexeme = lx:next(false, true)
	local ty = lexeme.type
	while ty == T.BrokenComment or ty == T.Comment or ty == T.BlockComment do
		local cur = lx.lexeme
		table.insert(self.comments, {
			kind = if cur.type == T.Comment then "comment" else "blockcomment",
			location = cur.location,
		})
		if cur.type == T.BrokenComment then
			return
		end
		lexeme = lx:next(false, false)
		ty = lexeme.type
	end
end

-- Create a token placeholder at `pos` (0-based) with literal `text`.
function Parser.tok(self, pos: Position, text: string): any
	local t = { _pos = copyPos(pos), text = text }
	table.insert(self.tokens, t)
	return t
end

function Parser.removeToken(self, tok: any)
	for i, t in self.tokens do
		if t == tok then
			table.remove(self.tokens, i)
			return
		end
	end
end

function Parser.expectAndConsume(self, ty: number): boolean
	if self:current().type ~= ty then
		return false
	end
	self:nextLexeme()
	return true
end

local function blockFollow(l: lexermod.Lexeme): boolean
	local t = l.type
	return t == T.Eof or t == T.ReservedElse or t == T.ReservedElseif or t == T.ReservedEnd or t == T.ReservedUntil
end

-- ===== Names / locals =====

-- Returns { name: string, location: Location } or nil.
function Parser.parseNameOpt(self): any?
	local cur = self:current()
	if cur.type ~= T.Name then
		return nil
	end
	local result = { name = cur.data :: string, location = cur.location }
	self:nextLexeme()
	return result
end

function Parser.parseName(self): any
	local n = self:parseNameOpt()
	if n then
		return n
	end
	local cur = self:current()
	return { name = "%error-id%", location = { begin = cur.location.begin, endPos = cur.location.begin } }
end

function Parser.parseIndexName(self, previous: Position): any
	local n = self:parseNameOpt()
	if n then
		return n
	end
	local cur = self:current()
	if cur.type >= T.ReservedAnd and cur.type <= T.ReservedWhile and cur.location.begin.line == previous.line then
		local result = { name = cur.data :: string, location = cur.location }
		self:nextLexeme()
		return result
	end
	return { name = "%error-id%", location = { begin = cur.location.begin, endPos = cur.location.begin } }
end

-- Create the CstLocal table for a binding, populated immediately (binding-site
-- first, matching the native serializer's traversal order). We model AstLocal
-- and its CstLocal as the same table identity so use-site references reuse it.
function Parser.pushLocal(self, binding: any, createToken: boolean?): any
	local ct = if createToken == nil then true else createToken
	local name = binding.name
	local prev = self.localMap[name.name]
	local localNode: any = {
		kind = "local",
		location = spanOf(name.location.begin, name.location.endPos),
		_functionDepth = #self.functionVarargStack - 1,
		_key = name.name,
	}
	if ct then
		localNode.name = self:tok(name.location.begin, name.name)
		if binding.annotation then
			localNode.colon = self:tok(binding.colonPosition, ":")
			localNode.annotation = binding.annotation
		else
			localNode.colon = nil
			localNode.annotation = nil
		end
	end
	localNode.shadows = prev
	self.localMap[name.name] = localNode
	table.insert(self.localStack, localNode)
	return localNode
end

function Parser.saveLocals(self): number
	return #self.localStack
end

function Parser.restoreLocals(self, offset: number)
	for i = #self.localStack, offset + 1, -1 do
		local l = self.localStack[i]
		self.localMap[l._key] = l.shadows
		self.localStack[i] = nil
	end
end

-- ===== Bindings =====

function Parser.parseOptionalType(self): any?
	if self:current().type == 58 then -- ':'
		self:nextLexeme()
		return self:parseType()
	end
	return nil
end

function Parser.parseBinding(self): any
	local name = self:parseNameOpt()
	if not name then
		local cur = self:current()
		name = { name = "%error-id%", location = cur.location }
	end
	local colonPosition: Position? = if self:current().type == 58 then self:current().location.begin else nil
	local annotation = self:parseOptionalType()
	return { name = name, annotation = annotation, colonPosition = colonPosition }
end

-- Parses a binding list; returns bindings plus comma positions.
function Parser.parseBindingList(self, result: { any }, commaPositions: { Position })
	while true do
		table.insert(result, self:parseBinding())
		if self:current().type ~= 44 then -- ','
			break
		end
		table.insert(commaPositions, self:current().location.begin)
		self:nextLexeme()
	end
end

-- ===== Expression lists =====

function Parser.parseExprList(self, result: { any }, commaPositions: { Position })
	table.insert(result, self:parseExpr(0))
	while self:current().type == 44 do -- ','
		table.insert(commaPositions, self:current().location.begin)
		self:nextLexeme()
		if self:current().type == 41 then -- ')'
			break
		end
		table.insert(result, self:parseExpr(0))
	end
end

-- Build a CstPunctuated table: items at [1..n] plus `separators` list of tokens.
function Parser.punctuated(self, nodes: { any }, separatorPositions: { Position }, separatorText: string): any
	local out = {}
	local separators = {}
	for i, node in nodes do
		out[i] = node
		if i <= #separatorPositions then
			table.insert(separators, self:tok(separatorPositions[i], separatorText))
		end
	end
	out.separators = separators
	return out
end

-- Punctuated specialized for locals (emits each local's name token in order).
function Parser.punctuatedLocals(self, locals: { any }, separatorPositions: { Position }): any
	local out = {}
	local separators = {}
	for i, localNode in locals do
		out[i] = localNode
		if i <= #separatorPositions then
			table.insert(separators, self:tok(separatorPositions[i], ","))
		end
	end
	out.separators = separators
	return out
end

-- ===== Statements =====

function Parser.parseChunk(self): any
	local block = self:parseBlock()
	return block
end

function Parser.parseBlock(self): any
	local localsBegin = self:saveLocals()
	local block = self:parseBlockNoScope()
	self:restoreLocals(localsBegin)
	return block
end

local function isStatLast(stat: any): boolean
	return stat.tag == "break" or stat.tag == "continue" or stat.tag == "return"
end

function Parser.parseBlockNoScope(self): any
	local body = {}
	local prevPosition = copyPos(self.lexer.prevLocation.endPos)

	while not blockFollow(self:current()) do
		local stat = self:parseStat()
		if self:current().type == 59 then -- ';'
			self:nextLexeme()
			local newEnd = copyPos(self.lexer.prevLocation.endPos)
			stat._locEnd = newEnd
			stat.location = spanOf(stat._locBegin, newEnd)
		end
		table.insert(body, stat)
		if isStatLast(stat) then
			break
		end
	end

	local endPos = copyPos(self:current().location.begin)
	return {
		kind = "stat",
		tag = "block",
		location = spanOf(prevPosition, endPos),
		statements = body,
		_locBegin = prevPosition,
		_locEnd = endPos,
	}
end

function Parser.parseStat(self): any
	local cur = self:current()
	local ty = cur.type

	if ty == T.ReservedLocal then
		return self:parseLocal(cur.location, false)
	elseif ty == T.ReservedReturn then
		return self:parseReturn()
	elseif ty == T.ReservedBreak then
		return self:parseBreak()
	elseif ty == T.ReservedDo then
		return self:parseDo()
	elseif ty == T.ReservedWhile then
		return self:parseWhile()
	elseif ty == T.ReservedRepeat then
		return self:parseRepeat()
	elseif ty == T.ReservedIf then
		return self:parseIf()
	elseif ty == T.ReservedFor then
		return self:parseFor()
	elseif ty == T.ReservedFunction then
		return self:parseFunctionStat()
	elseif ty == T.Attribute or ty == T.AttributeOpen then
		return self:parseAttributeStat()
	end

	local start = cur.location
	local expr = self:parsePrimaryExpr(true)

	if expr.tag == "call" then
		return {
			kind = "stat",
			tag = "expression",
			location = expr.location,
			expression = expr,
			_locBegin = expr._locBegin,
			_locEnd = expr._locEnd,
		}
	end

	local ct = self:current().type
	if ct == 44 or ct == 61 then -- ',' or '='
		return self:parseAssignment(expr)
	end

	local cop = compoundOpText(ct)
	if cop then
		return self:parseCompoundAssignment(expr, cop)
	end

	-- Context-sensitive keywords (continue / type / const / export) land here.
	-- The speculative primary-expr created a global name token placeholder; drop
	-- it since these keywords emit their own keyword tokens instead.
	local ident = (expr.tag == "global" and expr._name) or nil
	if ident == "type" or ident == "export" or ident == "continue" or ident == "const" then
		self:removeToken(expr.name)
	end
	if ident == "type" then
		return self:parseTypeAlias(expr, false, expr._locBegin)
	end
	if ident == "export" then
		local cu = self:current()
		if cu.type == T.Name and cu.data == "type" then
			local typeKeywordBegin = copyPos(cu.location.begin)
			self:nextLexeme()
			return self:parseTypeAlias(expr, true, typeKeywordBegin)
		end
	end
	if ident == "continue" then
		return self:parseContinue(expr)
	end
	if ident == "const" then
		return self:parseLocal({ begin = expr._locBegin, endPos = expr._locEnd }, true)
	end

	error("parseStat: unsupported statement starting at line " .. tostring(start.begin.line + 1))
end

-- Parses a (possibly empty) generic type list `<T, U, V...>`. For function
-- bodies `withDefaultValues` is false, so no type parsing is required.
function Parser.parseGenericTypeList(self, withDefaultValues: boolean): any
	local generics = {}
	local genericPacks = {}
	local openPos: Position? = nil
	local commaPositions = {}
	local closePos: Position? = nil

	if self:current().type == 60 then -- '<'
		openPos = copyPos(self:current().location.begin)
		self:nextLexeme()
		while true do
			local nameLoc = self:current().location
			local name = self:parseName()
			if self:current().type == T.Dot3 then
				local ellipsisBegin = copyPos(self:current().location.begin)
				self:nextLexeme()
				local packNode: any = {
					tag = "generic",
					kind = "typepack",
					location = spanOf(name.location.begin, name.location.endPos),
					name = self:tok(name.location.begin, name.name),
					ellipsis = self:tok(ellipsisBegin, "..."),
				}
				if withDefaultValues and self:current().type == 61 then -- '='
					local eqBegin = copyPos(self:current().location.begin)
					self:nextLexeme()
					packNode.equals = self:tok(eqBegin, "=")
					if self:shouldParseTypePack() then
						packNode.default = self:parseTypePack()
					else
						packNode.default = self:parseSimpleTypeOrPack().typePack
					end
				end
				table.insert(genericPacks, packNode)
			else
				local genNode: any = {
					tag = "generic",
					kind = "type",
					location = spanOf(name.location.begin, name.location.endPos),
					name = self:tok(name.location.begin, name.name),
					equals = nil,
					default = nil,
				}
				if withDefaultValues and self:current().type == 61 then -- '='
					local eqBegin = copyPos(self:current().location.begin)
					self:nextLexeme()
					genNode.equals = self:tok(eqBegin, "=")
					genNode.default = self:parseType()
				end
				table.insert(generics, genNode)
			end

			if self:current().type == 44 then -- ','
				table.insert(commaPositions, self:current().location.begin)
				self:nextLexeme()
				if self:current().type == 62 then -- '>'
					break
				end
			else
				break
			end
		end
		local closeFound = self:current().type == 62
		local closeBegin = copyPos(self:current().location.begin)
		self:expectAndConsume(62) -- '>'
		if closeFound then
			closePos = closeBegin
		end
	end

	return {
		generics = generics,
		genericPacks = genericPacks,
		openPos = openPos,
		commaPositions = commaPositions,
		closePos = closePos,
	}
end

local function splitArray(arr: { any }, index: number): { any }
	if #arr < index then
		return arr
	end
	local out = {}
	for i = index + 1, #arr do
		table.insert(out, arr[i])
	end
	return out
end

-- Parses `(params) [: ret] block end`. Returns (funcExprNode, funcLocal?).
function Parser.parseFunctionBody(self, hasself: boolean, matchFunctionBegin: Position, startLoc: any, localBinding: any?, isConst: boolean, attributes: { any }): (any, any?)
	-- When attributes are present, the function's start location is the first
	-- attribute's location (matching Luau's parseFunctionBody).
	if #attributes > 0 then
		startLoc = { begin = copyPos(attributes[1]._locBegin), endPos = copyPos(attributes[1]._locEnd) }
	end
	local startBegin = copyPos(startLoc.begin)
	local gen = self:parseGenericTypeList(false)

	local openParenBegin = copyPos(self:current().location.begin)
	local matchParenIsParen = self:current().type == 40
	self:expectAndConsume(40) -- '('

	local args = {}
	local argsCommaPositions = {}
	local vararg = false
	local varargBegin: Position? = nil
	local varargAnnotation: any = nil
	local varargColonPos: Position? = nil

	if self:current().type ~= 41 then -- ')'
		-- binding list with '...'
		while true do
			if self:current().type == T.Dot3 then
				vararg = true
				varargBegin = copyPos(self:current().location.begin)
				self:nextLexeme()
				if self:current().type == 58 then -- ':' vararg annotation (deferred)
					varargColonPos = copyPos(self:current().location.begin)
					self:nextLexeme()
					varargAnnotation = self:parseVariadicArgumentTypePack()
				end
				break
			end
			table.insert(args, self:parseBinding())
			if self:current().type ~= 44 then
				break
			end
			table.insert(argsCommaPositions, self:current().location.begin)
			self:nextLexeme()
		end
	end

	local argLocation: any = nil
	if matchParenIsParen and self:current().type == 41 then
		argLocation = { begin = openParenBegin, endPos = copyPos(self:current().location.endPos) }
	end
	self:expectAndConsume(41) -- ')'

	local returnSpecifierPos: Position? = nil
	local returnAnnotation: any = nil
	-- parseOptionalReturnType: only when ':' or '->' (deferred full impl)
	if self:current().type == 58 or self:current().type == T.SkinnyArrow then
		returnSpecifierPos = copyPos(self:current().location.begin)
		self:nextLexeme()
		returnAnnotation = self:parseReturnType()
	end

	local funLocal: any = nil
	if localBinding then
		funLocal = self:pushLocal(localBinding)
	end

	local localsBegin = self:saveLocals()
	table.insert(self.functionVarargStack, vararg)

	local selfLocal: any = nil
	if hasself then
		selfLocal = self:pushLocal({
			name = { name = "self", location = { begin = copyPos(startLoc.begin), endPos = copyPos(startLoc.endPos) } },
			annotation = nil,
			colonPosition = nil,
		}, false)
	end
	local vars = {}
	local colonPositions = {}
	for _, binding in args do
		table.insert(vars, self:pushLocal(binding))
		table.insert(colonPositions, binding.colonPosition)
	end

	local body = self:parseBlock()

	self.functionVarargStack[#self.functionVarargStack] = nil
	self:restoreLocals(localsBegin)

	local endLoc = self:current().location
	self:expectAndConsume(T.ReservedEnd)
	local endPos = copyPos(endLoc.endPos)

	local node: any = {
		kind = "expr",
		tag = "function",
		location = spanOf(startBegin, endPos),
		_locBegin = copyPos(startBegin),
		_locEnd = endPos,
		attributes = attributes,
		functionKeyword = self:tok(matchFunctionBegin, "function"),
	}

	if #gen.generics > 0 or #gen.genericPacks > 0 then
		node.openGenerics = self:tok(gen.openPos :: Position, "<")
		node.generics = self:punctuated(gen.generics, gen.commaPositions, ",")
		node.genericPacks = self:punctuated(gen.genericPacks, splitArray(gen.commaPositions, #gen.generics), ",")
		node.closeGenerics = self:tok(gen.closePos :: Position, ">")
	else
		node.generics = {}
		node.genericPacks = {}
	end

	if selfLocal then
		node.self = selfLocal
	else
		node.self = nil
	end

	if argLocation then
		node.openParens = self:tok(argLocation.begin, "(")
	end

	node.parameters = self:punctuatedLocals(vars, argsCommaPositions)

	node.hasVararg = vararg
	if vararg then
		node.vararg = self:tok(varargBegin :: Position, "...")
	else
		node.vararg = nil
	end
	node.varargColon = if varargColonPos then self:tok(varargColonPos, ":") else nil
	node.varargAnnotation = varargAnnotation

	if argLocation then
		node.closeParens = self:tok({ line = argLocation.endPos.line, column = argLocation.endPos.column - 1 }, ")")
	end

	node.returnSpecifier = if returnSpecifierPos then self:tok(returnSpecifierPos, ":") else nil
	node.returnAnnotation = returnAnnotation

	node.body = body
	node.endKeyword = self:tok(body._locEnd, "end")

	return node, funLocal
end

function Parser.parseFunctionName(self): (any, boolean)
	local startBegin = copyPos(self:current().location.begin)
	local expr = self:parseNameExpr()
	local hasself = false

	while self:current().type == 46 do -- '.'
		local opBegin = copyPos(self:current().location.begin)
		self:nextLexeme()
		local name = self:parseName()
		expr = {
			kind = "expr",
			tag = "indexname",
			location = spanOf(startBegin, name.location.endPos),
			_locBegin = startBegin,
			_locEnd = copyPos(name.location.endPos),
			expression = expr,
			accessor = self:tok(opBegin, "."),
			index = self:tok(name.location.begin, name.name),
			indexLocation = spanOf(name.location.begin, name.location.endPos),
		}
	end

	if self:current().type == 58 then -- ':'
		local opBegin = copyPos(self:current().location.begin)
		self:nextLexeme()
		local name = self:parseName()
		expr = {
			kind = "expr",
			tag = "indexname",
			location = spanOf(startBegin, name.location.endPos),
			_locBegin = startBegin,
			_locEnd = copyPos(name.location.endPos),
			expression = expr,
			accessor = self:tok(opBegin, ":"),
			index = self:tok(name.location.begin, name.name),
			indexLocation = spanOf(name.location.begin, name.location.endPos),
		}
		hasself = true
	end

	return expr, hasself
end

function Parser.parseAttribute(self): any
	local cur = self:current()
	local loc = cur.location
	local name = cur.data :: string
	self:nextLexeme()
	return {
		kind = "attribute",
		location = spanOf(loc.begin, loc.endPos),
		name = self:tok(loc.begin, "@" .. name),
		_locBegin = copyPos(loc.begin),
		_locEnd = copyPos(loc.endPos),
	}
end

function Parser.parseAttributes(self): { any }
	local attributes = {}
	while true do
		local t = self:current().type
		if t == T.Attribute then
			table.insert(attributes, self:parseAttribute())
		elseif t == T.AttributeOpen then
			error("'@[...]' attribute lists not implemented yet")
		else
			break
		end
	end
	return attributes
end

function Parser.parseAttributeStat(self): any
	-- startLocation is the first `@`, i.e. the attribute start location.
	local startLocation = self:current().location
	local attributes = self:parseAttributes()
	local attrStart = { begin = copyPos(startLocation.begin), endPos = copyPos(startLocation.endPos) }

	local t = self:current().type
	if t == T.ReservedFunction then
		return self:parseFunctionStat(attributes, attrStart)
	elseif t == T.ReservedLocal then
		return self:parseLocal(attrStart, false, attributes, copyPos(self:current().location.begin))
	elseif t == T.Name and self:current().data == "const" then
		local kwLoc = self:current().location
		self:nextLexeme()
		return self:parseLocal({ begin = attrStart.begin, endPos = kwLoc.endPos }, true, attributes, kwLoc.begin)
	end
	error("parseAttributeStat: unexpected token after attributes at line " .. tostring(startLocation.begin.line + 1))
end

function Parser.parseFunctionStat(self, attributes: { any }?, startLocOverride: any?): any
	local attrs = attributes or {}
	local funcKwLoc = self:current().location
	local matchFunctionBegin = copyPos(funcKwLoc.begin)
	local startLoc = startLocOverride or { begin = copyPos(funcKwLoc.begin), endPos = copyPos(funcKwLoc.endPos) }
	self:nextLexeme() -- 'function'

	local nameExpr, hasself = self:parseFunctionName()
	local body = self:parseFunctionBody(hasself, matchFunctionBegin, startLoc, nil, false, attrs)

	return {
		kind = "stat",
		tag = "function",
		location = spanOf(startLoc.begin, body._locEnd),
		_locBegin = copyPos(startLoc.begin),
		_locEnd = body._locEnd,
		name = nameExpr,
		func = body,
	}
end

function Parser.parseTypeFunction(self, startBegin: Position, exported: boolean, typeKeywordBegin: Position): any
	local matchFnLoc = self:current().location
	local matchFnBegin = copyPos(matchFnLoc.begin)
	self:nextLexeme() -- 'function'
	local name = self:parseNameOpt()
	if not name then
		local cur = self:current()
		name = { name = "%error-id%", location = cur.location }
	end
	local body = self:parseFunctionBody(false, matchFnBegin, { begin = copyPos(matchFnBegin), endPos = copyPos(matchFnLoc.endPos) }, nil, false, {})
	return {
		kind = "stat",
		tag = "typefunction",
		location = spanOf(startBegin, body._locEnd),
		_locBegin = copyPos(startBegin),
		_locEnd = body._locEnd,
		isExported = exported,
		export = if exported then self:tok(startBegin, "export") else nil,
		type = self:tok(typeKeywordBegin, "type"),
		name = self:tok(name.location.begin, name.name),
		body = body,
	}
end

function Parser.parseTypeAlias(self, expr: any, exported: boolean, typeKeywordBegin: Position): any
	if self:current().type == T.ReservedFunction then
		return self:parseTypeFunction(copyPos(expr._locBegin), exported, typeKeywordBegin)
	end

	local startBegin = copyPos(expr._locBegin)
	local name = self:parseNameOpt()
	if not name then
		local cur = self:current()
		name = { name = "%error-id%", location = cur.location }
	end

	local gen = self:parseGenericTypeList(true)

	local equalsFound = self:current().type == 61
	local equalsBegin = copyPos(self:current().location.begin)
	self:expectAndConsume(61) -- '='
	local ty = self:parseType()

	local node: any = {
		kind = "stat",
		tag = "typealias",
		location = spanOf(startBegin, ty._locEnd),
		_locBegin = startBegin,
		_locEnd = ty._locEnd,
		isExported = exported,
		export = if exported then self:tok(startBegin, "export") else nil,
		typeToken = self:tok(typeKeywordBegin, "type"),
		name = self:tok(name.location.begin, name.name),
	}
	if #gen.generics > 0 or #gen.genericPacks > 0 then
		node.openGenerics = self:tok(gen.openPos :: Position, "<")
		node.generics = self:punctuated(gen.generics, gen.commaPositions, ",")
		node.genericPacks = self:punctuated(gen.genericPacks, splitArray(gen.commaPositions, #gen.generics), ",")
		node.closeGenerics = self:tok(gen.closePos :: Position, ">")
	end
	node.equals = if equalsFound then self:tok(equalsBegin, "=") else nil
	node.type = ty
	return node
end

function Parser.parseLocal(self, start: lexermod.Location, isConst: boolean, attributes: { any }?, keywordBeginArg: Position?): any
	if not isConst then
		self:nextLexeme() -- 'local'
	end
	local keywordBegin = keywordBeginArg or copyPos(start.begin)
	local attrs = attributes or {}

	if self:current().type == T.ReservedFunction then
		local funcKwLoc = self:current().location
		local matchFunctionBegin = copyPos(funcKwLoc.begin)
		self:nextLexeme() -- 'function'
		local name = self:parseName()
		local binding = { name = name, annotation = nil, colonPosition = nil }
		-- Luau patches the function start column to the `local`/attr column (same
		-- line) so missing-`end` recovery works; this affects the func expr begin.
		local patchedBegin = {
			line = funcKwLoc.begin.line,
			column = if funcKwLoc.begin.line == keywordBegin.line then keywordBegin.column else funcKwLoc.begin.column,
		}
		local startLoc = { begin = patchedBegin, endPos = copyPos(funcKwLoc.endPos) }
		local body, funLocal = self:parseFunctionBody(false, matchFunctionBegin, startLoc, binding, isConst, attrs)
		return {
			kind = "stat",
			tag = "localfunction",
			location = spanOf(start.begin, body._locEnd),
			_locBegin = copyPos(start.begin),
			_locEnd = body._locEnd,
			localKeyword = self:tok(keywordBegin, "local"),
			name = funLocal,
			func = body,
		}
	end

	local names = {}
	local varsCommaPositions = {}
	self:parseBindingList(names, varsCommaPositions)

	local values = {}
	local valuesCommaPositions = {}
	local equalsLocation: lexermod.Location? = nil

	if self:current().type == 61 then -- '='
		equalsLocation = self:current().location
		self:nextLexeme()
		self:parseExprList(values, valuesCommaPositions)
	end

	local vars = {}
	for _, binding in names do
		table.insert(vars, self:pushLocal(binding))
	end

	local endLoc: lexermod.Location
	if #values == 0 then
		endLoc = self.lexer.prevLocation
	else
		endLoc = { begin = values[#values]._locBegin, endPos = values[#values]._locEnd }
	end

	local keyword = if isConst then "const" else "local"
	local colonPositions = {}
	for _, binding in names do
		table.insert(colonPositions, binding.colonPosition)
	end

	local node: any = {
		kind = "stat",
		tag = keyword,
		location = spanOf(start.begin, endLoc.endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = copyPos(endLoc.endPos),
	}
	node[if isConst then "constKeyword" else "localKeyword"] = self:tok(keywordBegin, keyword)
	node.variables = self:punctuatedLocals(vars, varsCommaPositions)
	node.equals = if equalsLocation then self:tok(equalsLocation.begin, "=") else nil
	node.values = self:punctuated(values, valuesCommaPositions, ",")
	return node
end

function Parser.parseReturn(self): any
	local start = self:current().location
	self:nextLexeme()

	local list = {}
	local commaPositions = {}
	if not blockFollow(self:current()) and self:current().type ~= 59 then
		self:parseExprList(list, commaPositions)
	end

	local endLoc = if #list == 0 then start else { begin = list[#list]._locBegin, endPos = list[#list]._locEnd }

	return {
		kind = "stat",
		tag = "return",
		location = spanOf(start.begin, endLoc.endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = copyPos(endLoc.endPos),
		returnKeyword = self:tok(start.begin, "return"),
		expressions = self:punctuated(list, commaPositions, ","),
	}
end

function Parser.parseBreak(self): any
	local start = self:current().location
	local node = {
		kind = "stat",
		tag = "break",
		location = spanOf(start.begin, start.endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = copyPos(start.endPos),
		token = self:tok(start.begin, "break"),
	}
	self:nextLexeme()
	return node
end

function Parser.parseContinue(self, expr: any): any
	return {
		kind = "stat",
		tag = "continue",
		location = expr.location,
		_locBegin = expr._locBegin,
		_locEnd = expr._locEnd,
		token = self:tok(expr._locBegin, "continue"),
	}
end

function Parser.parseDo(self): any
	local start = self:current().location
	local doToken = self:tok(start.begin, "do")
	self:nextLexeme()

	local body = self:parseBlock()
	local endBegin = copyPos(self:current().location.begin)
	self:expectAndConsume(T.ReservedEnd)
	local endPos = copyPos(self.lexer.prevLocation.endPos)

	-- CstStatDo: the inner block's location spans its statements (or the do
	-- node when empty), matching the native serializer.
	local blockLoc
	if #body.statements > 0 then
		blockLoc = { begin = body.statements[1]._locBegin, endPos = body.statements[#body.statements]._locEnd }
	else
		blockLoc = { begin = copyPos(start.begin), endPos = endPos }
	end
	body.location = spanOf(blockLoc.begin, blockLoc.endPos)

	return {
		kind = "stat",
		tag = "do",
		location = spanOf(start.begin, endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = endPos,
		doKeyword = doToken,
		body = body,
		endKeyword = self:tok(endBegin, "end"),
	}
end

function Parser.parseWhile(self): any
	local start = self:current().location
	local whileToken = self:tok(start.begin, "while")
	self:nextLexeme()

	local condition = self:parseExpr(0)

	local hasDo = self:current().type == T.ReservedDo
	local doToken = if hasDo then self:tok(self:current().location.begin, "do") else nil
	self:expectAndConsume(T.ReservedDo)

	local body = self:parseBlock()
	local endBegin = copyPos(self:current().location.begin)
	self:expectAndConsume(T.ReservedEnd)
	local endPos = copyPos(self.lexer.prevLocation.endPos)

	return {
		kind = "stat",
		tag = "while",
		location = spanOf(start.begin, endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = endPos,
		whileKeyword = whileToken,
		condition = condition,
		doKeyword = doToken,
		body = body,
		endKeyword = self:tok(body._locEnd, "end"),
	}
end

function Parser.parseRepeat(self): any
	local start = self:current().location
	local repeatToken = self:tok(start.begin, "repeat")
	self:nextLexeme()

	local localsBegin = self:saveLocals()
	local body = self:parseBlockNoScope()

	local hasUntil = self:current().type == T.ReservedUntil
	local untilBegin = copyPos(self:current().location.begin)
	self:expectAndConsume(T.ReservedUntil)
	local untilToken = self:tok(untilBegin, "until")

	local condition = self:parseExpr(0)
	self:restoreLocals(localsBegin)

	return {
		kind = "stat",
		tag = "repeat",
		location = spanOf(start.begin, condition._locEnd),
		_locBegin = copyPos(start.begin),
		_locEnd = condition._locEnd,
		repeatKeyword = repeatToken,
		body = body,
		untilKeyword = untilToken,
		condition = condition,
	}
end

-- Parses an if/elseif chain into a raw nested node (tag "ifraw"); the statement
-- entry point flattens it into the CST's `elseifs` list.
function Parser.parseIfRaw(self): any
	local start = self:current().location
	self:nextLexeme() -- 'if' / 'elseif'

	local cond = self:parseExpr(0)

	local thenPos = copyPos(self:current().location.begin)
	self:expectAndConsume(T.ReservedThen)
	local thenbody = self:parseBlock()

	local node: any = {
		tag = "ifraw",
		condition = cond,
		thenPos = thenPos,
		thenbody = thenbody,
		elsePos = nil,
		elsebody = nil,
		_locBegin = copyPos(start.begin),
	}

	if self:current().type == T.ReservedElseif then
		node.elsePos = copyPos(self:current().location.begin)
		local elsebody = self:parseIfRaw()
		node.elsebody = elsebody
		node._locEnd = elsebody._locEnd
	else
		if self:current().type == T.ReservedElse then
			node.elsePos = copyPos(self:current().location.begin)
			local elseTokEnd = copyPos(self:current().location.endPos)
			self:nextLexeme()
			local elseBlock = self:parseBlock()
			-- Luau patches the else block's begin to the `else` token end.
			elseBlock._locBegin = elseTokEnd
			elseBlock.location = spanOf(elseTokEnd, elseBlock._locEnd)
			node.elsebody = elseBlock
		end
		local endLoc = self:current().location
		self:expectAndConsume(T.ReservedEnd)
		node._locEnd = copyPos(endLoc.endPos)
	end

	node.location = spanOf(start.begin, node._locEnd)
	return node
end

function Parser.parseIf(self): any
	local raw = self:parseIfRaw()

	local node: any = {
		kind = "stat",
		tag = "conditional",
		location = raw.location,
		_locBegin = raw._locBegin,
		_locEnd = raw._locEnd,
		ifKeyword = self:tok(raw._locBegin, "if"),
		condition = raw.condition,
		thenKeyword = self:tok(raw.thenPos, "then"),
		thenBlock = raw.thenbody,
	}

	local elseifs = {}
	local cur = raw
	while cur.elsebody and cur.elsebody.tag == "ifraw" do
		local e = cur.elsebody
		table.insert(elseifs, {
			elseIfKeyword = self:tok(e._locBegin, "elseif"),
			condition = e.condition,
			thenKeyword = self:tok(e.thenPos, "then"),
			thenBlock = e.thenbody,
		})
		cur = e
	end
	node.elseifs = elseifs

	if cur.elsebody then
		node.elseKeyword = self:tok(cur.elsePos, "else")
		node.elseBlock = cur.elsebody
		node.endKeyword = self:tok(cur.elsebody._locEnd, "end")
	else
		node.elseKeyword = nil
		node.elseBlock = nil
		node.endKeyword = self:tok(cur.thenbody._locEnd, "end")
	end

	return node
end

function Parser.parseFor(self): any
	local start = self:current().location
	self:nextLexeme() -- 'for'

	local varname = self:parseBinding()

	if self:current().type == 61 then -- '=' numeric for
		local equalsBegin = copyPos(self:current().location.begin)
		self:nextLexeme()
		local from = self:parseExpr(0)
		local endCommaBegin = copyPos(self:current().location.begin)
		local hasEndComma = self:current().type == 44
		self:expectAndConsume(44) -- ','
		local to = self:parseExpr(0)

		local stepCommaBegin: Position? = nil
		local step: any = nil
		if self:current().type == 44 then
			stepCommaBegin = copyPos(self:current().location.begin)
			self:nextLexeme()
			step = self:parseExpr(0)
		end

		local hasDo = self:current().type == T.ReservedDo
		local doBegin = copyPos(self:current().location.begin)
		self:expectAndConsume(T.ReservedDo)

		local localsBegin = self:saveLocals()
		local var = self:pushLocal(varname)
		local body = self:parseBlock()
		self:restoreLocals(localsBegin)

		local endLoc = self:current().location
		self:expectAndConsume(T.ReservedEnd)
		local endPos = copyPos(endLoc.endPos)

		return {
			kind = "stat",
			tag = "for",
			location = spanOf(start.begin, endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = endPos,
			forKeyword = self:tok(start.begin, "for"),
			variable = var,
			equals = self:tok(equalsBegin, "="),
			from = from,
			toComma = self:tok(endCommaBegin, ","),
			to = to,
			stepComma = if stepCommaBegin then self:tok(stepCommaBegin, ",") else nil,
			step = step,
			doKeyword = if hasDo then self:tok(doBegin, "do") else nil,
			body = body,
			endKeyword = self:tok(body._locEnd, "end"),
		}
	else
		local names = { varname }
		local varsCommaPositions = {}
		if self:current().type == 44 then -- ','
			table.insert(varsCommaPositions, self:current().location.begin)
			self:nextLexeme()
			self:parseBindingList(names, varsCommaPositions)
		end

		local hasIn = self:current().type == T.ReservedIn
		local inBegin = copyPos(self:current().location.begin)
		self:expectAndConsume(T.ReservedIn)

		local values = {}
		local valuesCommaPositions = {}
		self:parseExprList(values, valuesCommaPositions)

		local hasDo = self:current().type == T.ReservedDo
		local doBegin = copyPos(self:current().location.begin)
		self:expectAndConsume(T.ReservedDo)

		local localsBegin = self:saveLocals()
		local vars = {}
		local colonPositions = {}
		for _, binding in names do
			table.insert(vars, self:pushLocal(binding))
			table.insert(colonPositions, binding.colonPosition)
		end

		local body = self:parseBlock()
		self:restoreLocals(localsBegin)

		local endLoc = self:current().location
		self:expectAndConsume(T.ReservedEnd)
		local endPos = copyPos(endLoc.endPos)

		return {
			kind = "stat",
			tag = "forin",
			location = spanOf(start.begin, endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = endPos,
			forKeyword = self:tok(start.begin, "for"),
			variables = self:punctuatedLocals(vars, varsCommaPositions),
			inKeyword = if hasIn then self:tok(inBegin, "in") else nil,
			values = self:punctuated(values, valuesCommaPositions, ","),
			doKeyword = if hasDo then self:tok(doBegin, "do") else nil,
			body = body,
			endKeyword = self:tok(body._locEnd, "end"),
		}
	end
end

function Parser.parseAssignment(self, initial: any): any
	local vars = { initial }
	local varsCommaPositions = {}
	while self:current().type == 44 do -- ','
		table.insert(varsCommaPositions, self:current().location.begin)
		self:nextLexeme()
		table.insert(vars, self:parsePrimaryExpr(true))
	end

	local equalsBegin = copyPos(self:current().location.begin)
	self:expectAndConsume(61) -- '='

	local values = {}
	local valuesCommaPositions = {}
	self:parseExprList(values, valuesCommaPositions)

	local last = values[#values]
	return {
		kind = "stat",
		tag = "assign",
		location = spanOf(initial._locBegin, last._locEnd),
		_locBegin = initial._locBegin,
		_locEnd = last._locEnd,
		variables = self:punctuated(vars, varsCommaPositions, ","),
		equals = self:tok(equalsBegin, "="),
		values = self:punctuated(values, valuesCommaPositions, ","),
	}
end

function Parser.parseCompoundAssignment(self, initial: any, opText: string): any
	local opBegin = copyPos(self:current().location.begin)
	self:nextLexeme()
	local value = self:parseExpr(0)
	return {
		kind = "stat",
		tag = "compoundassign",
		location = spanOf(initial._locBegin, value._locEnd),
		_locBegin = initial._locBegin,
		_locEnd = value._locEnd,
		variable = initial,
		operator = self:tok(opBegin, opText .. "="),
		value = value,
	}
end

-- ===== Expressions =====

function Parser.parseExpr(self, limit: number): any
	local startLoc = self:current().location
	local expr: any

	local uop = unaryOpText(self:current().type)
	if uop then
		local opBegin = copyPos(self:current().location.begin)
		self:nextLexeme()
		local subexpr = self:parseExpr(8)
		expr = {
			kind = "expr",
			tag = "unary",
			location = spanOf(startLoc.begin, subexpr._locEnd),
			_locBegin = copyPos(startLoc.begin),
			_locEnd = subexpr._locEnd,
			operator = self:tok(opBegin, uop),
			operand = subexpr,
		}
	else
		expr = self:parseAssertionExpr()
	end

	local opKey = binaryOpKey(self:current().type)
	while opKey and BINARY[opKey].left > limit do
		local info = BINARY[opKey]
		local opBegin = copyPos(self:current().location.begin)
		self:nextLexeme()
		local rhs = self:parseExpr(info.right)
		expr = {
			kind = "expr",
			tag = "binary",
			location = spanOf(expr._locBegin, rhs._locEnd),
			_locBegin = expr._locBegin,
			_locEnd = rhs._locEnd,
			lhsOperand = expr,
			operator = self:tok(opBegin, info.text),
			rhsOperand = rhs,
		}
		opKey = binaryOpKey(self:current().type)
	end

	return expr
end

function Parser.parseIfElseExprRaw(self): any
	local start = self:current().location
	self:nextLexeme() -- 'if' / 'elseif'
	local condition = self:parseExpr(0)
	local hasThen = self:current().type == T.ReservedThen
	self:expectAndConsume(T.ReservedThen)
	local thenPos = if hasThen then self:prevBegin() else nil
	local trueExpr = self:parseExpr(0)

	local elsePos = copyPos(self:current().location.begin)
	local hasElse = false
	local isElseIf = false
	local falseExpr: any
	if self:current().type == T.ReservedElseif then
		hasElse = true
		isElseIf = true
		falseExpr = self:parseIfElseExprRaw()
	else
		hasElse = self:current().type == T.ReservedElse
		self:expectAndConsume(T.ReservedElse)
		falseExpr = self:parseExpr(0)
	end

	return {
		tag = "ifelseraw",
		_locBegin = copyPos(start.begin),
		_locEnd = falseExpr._locEnd,
		condition = condition,
		hasThen = hasThen,
		thenPos = thenPos,
		trueExpr = trueExpr,
		hasElse = hasElse,
		elsePos = elsePos,
		isElseIf = isElseIf,
		falseExpr = falseExpr,
	}
end

function Parser.parseIfElseExpr(self): any
	local raw = self:parseIfElseExprRaw()
	local node: any = {
		kind = "expr",
		tag = "conditional",
		location = spanOf(raw._locBegin, raw._locEnd),
		_locBegin = raw._locBegin,
		_locEnd = raw._locEnd,
		ifKeyword = self:tok(raw._locBegin, "if"),
		condition = raw.condition,
	}
	node.thenKeyword = if raw.hasThen then self:tok(raw.thenPos, "then") else nil
	node.thenExpr = if raw.hasThen then raw.trueExpr else nil

	local elseifs = {}
	local cur = raw
	while cur.hasElse and cur.falseExpr.tag == "ifelseraw" and cur.isElseIf do
		local e = cur.falseExpr
		local entry: any = {
			elseIfKeyword = self:tok(e._locBegin, "elseif"),
			condition = e.condition,
		}
		entry.thenKeyword = if e.hasThen then self:tok(e.thenPos, "then") else nil
		entry.thenExpr = if e.hasThen then e.trueExpr else nil
		table.insert(elseifs, entry)
		cur = e
	end
	node.elseifs = elseifs

	if cur.hasElse then
		node.elseKeyword = self:tok(cur.elsePos, "else")
		node.elseExpr = cur.falseExpr
	else
		node.elseKeyword = nil
		node.elseExpr = nil
	end
	return node
end

function Parser.parseExplicitTypeInstantiationExpr(self, startBegin: Position, baseExpr: any): any
	local la1Begin = copyPos(self:current().location.begin) -- first '<'
	self:nextLexeme() -- consume first '<'
	local tp = self:parseTypeParams() -- consumes second '<' .. first '>'
	local ra2Begin = copyPos(self:current().location.begin) -- second '>'
	local endLoc = self:current().location
	self:expectAndConsume(62) -- second '>'
	return {
		kind = "expr",
		tag = "instantiate",
		location = spanOf(startBegin, endLoc.endPos),
		_locBegin = copyPos(startBegin),
		_locEnd = copyPos(endLoc.endPos),
		expr = baseExpr,
		leftArrow1 = self:tok(la1Begin, "<"),
		leftArrow2 = self:tok(tp.openPos :: Position, "<"),
		typeArguments = self:punctuated(tp.params, tp.commaPositions, ","),
		rightArrow1 = self:tok(tp.closePos :: Position, ">"),
		rightArrow2 = self:tok(ra2Begin, ">"),
	}
end

function Parser.parseAssertionExpr(self): any
	local start = self:current().location
	local expr = self:parseSimpleExpr()
	if self:current().type == T.DoubleColon then
		local opBegin = copyPos(self:current().location.begin)
		self:nextLexeme()
		local annotation = self:parseType()
		return {
			kind = "expr",
			tag = "cast",
			location = spanOf(start.begin, annotation._locEnd),
			_locBegin = copyPos(start.begin),
			_locEnd = annotation._locEnd,
			operand = expr,
			operator = self:tok(opBegin, "::"),
			annotation = annotation,
		}
	end
	return expr
end

function Parser.parseNameExpr(self): any
	local name = self:parseNameOpt()
	if not name then
		local cur = self:current()
		return {
			kind = "expr",
			tag = "global",
			location = spanOf(cur.location.begin, cur.location.begin),
			_locBegin = copyPos(cur.location.begin),
			_locEnd = copyPos(cur.location.begin),
			name = self:tok(cur.location.begin, "%error-id%"),
			_name = "%error-id%",
		}
	end
	local localNode = self.localMap[name.name]
	if localNode then
		return {
			kind = "expr",
			tag = "local",
			location = spanOf(name.location.begin, name.location.endPos),
			_locBegin = copyPos(name.location.begin),
			_locEnd = copyPos(name.location.endPos),
			token = self:tok(name.location.begin, name.name),
			["local"] = localNode,
			upvalue = localNode._functionDepth ~= (#self.functionVarargStack - 1),
		}
	end
	return {
		kind = "expr",
		tag = "global",
		location = spanOf(name.location.begin, name.location.endPos),
		_locBegin = copyPos(name.location.begin),
		_locEnd = copyPos(name.location.endPos),
		name = self:tok(name.location.begin, name.name),
		_name = name.name,
	}
end

function Parser.parsePrefixExpr(self): any
	if self:current().type == 40 then -- '('
		local start = copyPos(self:current().location.begin)
		local openToken = self:tok(start, "(")
		self:nextLexeme()
		local expr = self:parseExpr(0)
		local endPos = copyPos(self:current().location.endPos)
		local closeBegin = copyPos(self:current().location.begin)
		local closeFound = self:current().type == 41
		if closeFound then
			self:nextLexeme()
		else
			endPos = copyPos(self.lexer.prevLocation.endPos)
		end
		return {
			kind = "expr",
			tag = "group",
			location = spanOf(start, endPos),
			_locBegin = start,
			_locEnd = endPos,
			openParens = openToken,
			expression = expr,
			closeParens = if closeFound then self:tok(closeBegin, ")") else nil,
		}
	end
	return self:parseNameExpr()
end

function Parser.parsePrimaryExpr(self, asStatement: boolean): any
	local start = copyPos(self:current().location.begin)
	local expr = self:parsePrefixExpr()

	while true do
		local ty = self:current().type
		if ty == 46 then -- '.'
			local opBegin = copyPos(self:current().location.begin)
			self:nextLexeme()
			local index = self:parseIndexName(opBegin)
			expr = {
				kind = "expr",
				tag = "indexname",
				location = spanOf(start, index.location.endPos),
				_locBegin = start,
				_locEnd = copyPos(index.location.endPos),
				expression = expr,
				accessor = self:tok(opBegin, "."),
				index = self:tok(index.location.begin, index.name),
				indexLocation = spanOf(index.location.begin, index.location.endPos),
			}
		elseif ty == 91 then -- '['
			expr = self:parseIndexExpr(start, expr)
		elseif ty == 58 then -- ':'
			expr = self:parseMethodCall(start, expr)
		elseif ty == 40 then -- '('
			if not asStatement and expr._locEnd.line ~= self:current().location.begin.line then
				break
			end
			expr = self:parseFunctionArgs(start, expr, false)
		elseif ty == 123 or ty == T.RawString or ty == T.QuotedString then -- '{' or string
			expr = self:parseFunctionArgs(start, expr, false)
		elseif ty == 60 and self:lookahead().type == 60 then -- '<' '<'
			expr = self:parseExplicitTypeInstantiationExpr(start, expr)
		else
			break
		end
	end

	return expr
end

function Parser.parseIndexExpr(self, start: Position, expr: any): any
	local openBegin = copyPos(self:current().location.begin)
	self:nextLexeme()
	local index = self:parseExpr(0)
	local closeBegin = copyPos(self:current().location.begin)
	local endPos = copyPos(self:current().location.endPos)
	local closeFound = self:current().type == 93
	self:expectAndConsume(93) -- ']'
	return {
		kind = "expr",
		tag = "index",
		location = spanOf(start, endPos),
		_locBegin = copyPos(start),
		_locEnd = endPos,
		expression = expr,
		openBrackets = self:tok(openBegin, "["),
		index = index,
		closeBrackets = if closeFound then self:tok(closeBegin, "]") else self:tok(closeBegin, "]"),
	}
end

function Parser.parseMethodCall(self, start: Position, expr: any): any
	local opBegin = copyPos(self:current().location.begin)
	self:nextLexeme()
	local index = self:parseIndexName(opBegin)
	local func = {
		kind = "expr",
		tag = "indexname",
		location = spanOf(start, index.location.endPos),
		_locBegin = copyPos(start),
		_locEnd = copyPos(index.location.endPos),
		expression = expr,
		accessor = self:tok(opBegin, ":"),
		index = self:tok(index.location.begin, index.name),
		indexLocation = spanOf(index.location.begin, index.location.endPos),
	}
	return self:parseFunctionArgs(start, func, true)
end

function Parser.parseFunctionArgs(self, start: Position, func: any, selfCall: boolean): any
	local cur = self:current()
	local args = {}
	local commaPositions = {}
	local openToken, closeToken
	local argStart, argEnd
	local endPos

	if cur.type == 40 then -- '('
		argStart = copyPos(cur.location.endPos)
		openToken = self:tok(cur.location.begin, "(")
		self:nextLexeme()
		if self:current().type ~= 41 then
			self:parseExprList(args, commaPositions)
		end
		-- `end` = the token where ')' is expected; argEnd / node end both use it.
		local closeBegin = copyPos(self:current().location.begin)
		argEnd = copyPos(self:current().location.endPos)
		endPos = copyPos(self:current().location.endPos)
		local closeFound = self:current().type == 41
		self:expectAndConsume(41) -- ')'
		closeToken = if closeFound then self:tok(closeBegin, ")") else nil
	elseif cur.type == 123 then -- '{'
		local braceStart = copyPos(cur.location.endPos)
		local tableExpr = self:parseTableConstructor()
		args = { tableExpr }
		argStart = braceStart
		argEnd = tableExpr._locEnd
		endPos = tableExpr._locEnd
	else -- string literal
		local strExpr = self:parseString()
		args = { strExpr }
		argStart = strExpr._locBegin
		argEnd = strExpr._locEnd
		endPos = strExpr._locEnd
	end

	return {
		kind = "expr",
		tag = "call",
		location = spanOf(func._locBegin, endPos),
		_locBegin = func._locBegin,
		_locEnd = endPos,
		func = func,
		openParens = openToken,
		arguments = self:punctuated(args, commaPositions, ","),
		self = selfCall,
		argLocation = spanOf(argStart, argEnd),
		closeParens = closeToken,
	}
end

-- Simple expressions.
function Parser.parseSimpleExpr(self): any
	local cur = self:current()
	local start = cur.location
	local ty = cur.type

	if ty == T.ReservedNil then
		self:nextLexeme()
		return {
			kind = "expr",
			tag = "nil",
			location = spanOf(start.begin, start.endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = copyPos(start.endPos),
			token = self:tok(start.begin, "nil"),
		}
	elseif ty == T.ReservedTrue or ty == T.ReservedFalse then
		local value = ty == T.ReservedTrue
		self:nextLexeme()
		return {
			kind = "expr",
			tag = "boolean",
			location = spanOf(start.begin, start.endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = copyPos(start.endPos),
			value = value,
			token = self:tok(start.begin, if value then "true" else "false"),
		}
	elseif ty == T.Number then
		return self:parseNumber()
	elseif ty == T.RawString or ty == T.QuotedString or ty == T.InterpStringSimple then
		return self:parseString()
	elseif ty == T.InterpStringBegin then
		return self:parseInterpString()
	elseif ty == T.ReservedFunction then
		local matchFunctionBegin = copyPos(start.begin)
		self:nextLexeme()
		local node = self:parseFunctionBody(false, matchFunctionBegin, { begin = start.begin, endPos = start.endPos }, nil, false, {})
		return node
	elseif ty == T.Dot3 then
		if not self.functionVarargStack[#self.functionVarargStack] then
			error("Cannot use '...' outside of a vararg function")
		end
		self:nextLexeme()
		return {
			kind = "expr",
			tag = "vararg",
			location = spanOf(start.begin, start.endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = copyPos(start.endPos),
			token = self:tok(start.begin, "..."),
		}
	elseif ty == 123 then -- '{'
		return self:parseTableConstructor()
	elseif ty == T.ReservedIf then
		return self:parseIfElseExpr()
	elseif ty == T.Attribute or ty == T.AttributeOpen then
		local attrs = self:parseAttributes()
		local funcKwLoc = self:current().location
		local matchFnBegin = copyPos(funcKwLoc.begin)
		self:nextLexeme() -- 'function'
		return self:parseFunctionBody(false, matchFnBegin, { begin = matchFnBegin, endPos = copyPos(funcKwLoc.endPos) }, nil, false, attrs)
	else
		return self:parsePrimaryExpr(false)
	end
end

local function stripUnderscores(s: string): string
	return (string.gsub(s, "_", ""))
end

function Parser.parseNumber(self): any
	local cur = self:current()
	local start = cur.location
	local sourceData = cur.data :: string
	local stripped = stripUnderscores(sourceData)

	local isInteger = string.sub(stripped, -1) == "i"
	local value: number
	local tag: string
	if isInteger then
		tag = "integer"
		local body = string.sub(stripped, 1, -2)
		local lower = string.lower(body)
		if string.sub(lower, 1, 2) == "0x" then
			value = tonumber(string.sub(body, 3), 16) or 0
		elseif string.sub(lower, 1, 2) == "0b" then
			value = tonumber(string.sub(body, 3), 2) or 0
		else
			value = tonumber(body) or 0
		end
	else
		tag = "number"
		local lower = string.lower(stripped)
		if string.sub(lower, 1, 2) == "0b" then
			value = tonumber(string.sub(stripped, 3), 2) or 0
		else
			value = tonumber(stripped) or 0
		end
	end

	self:nextLexeme()
	return {
		kind = "expr",
		tag = tag,
		location = spanOf(start.begin, start.endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = copyPos(start.endPos),
		value = value,
		token = self:tok(start.begin, sourceData),
	}
end

-- 0-based source byte offset of a position.
function Parser.offsetOfPos(self, p: Position): number
	return self.lineOffsets[p.line + 1] + p.column
end

function Parser.byteAtPos(self, p: Position): number
	return string.byte(self.source, self:offsetOfPos(p) + 1) or 0
end

function Parser.parseString(self): any
	local cur = self:current()
	local loc = cur.location
	local data = cur.data :: string
	local ty = cur.type

	local quoteStyle: string
	local blockDepth = 0
	if ty == T.QuotedString then
		local q = self:byteAtPos(loc.begin)
		quoteStyle = if q == 34 then "double" else "single"
	elseif ty == T.InterpStringSimple then
		quoteStyle = "interp"
	else -- RawString
		quoteStyle = "block"
		-- Count '=' between the opening brackets: '[' '='* '['.
		local off = self:offsetOfPos(loc.begin) + 1 -- skip first '['
		while string.byte(self.source, off + 1) == 61 do -- '='
			blockDepth += 1
			off += 1
		end
	end

	self:nextLexeme()

	local tokPlaceholder = self:tok(loc.begin, data)
	tokPlaceholder._forceEnd = copyPos(loc.endPos)

	return {
		kind = "expr",
		tag = "string",
		location = spanOf(loc.begin, loc.endPos),
		_locBegin = copyPos(loc.begin),
		_locEnd = copyPos(loc.endPos),
		quoteStyle = quoteStyle,
		blockDepth = blockDepth,
		value = tokPlaceholder,
	}
end

function Parser.parseInterpString(self): any
	local start = self:current().location
	local strings = {}
	local expressions = {}
	local endLoc = start

	while true do
		local cur = self:current()
		endLoc = cur.location
		local strTok = self:tok(cur.location.begin, cur.data :: string)
		strTok._interpAdjust = true
		table.insert(strings, strTok)
		local wasEnd = cur.type == T.InterpStringEnd or cur.type == T.InterpStringSimple
		self:nextLexeme()
		if wasEnd then
			break
		end
		table.insert(expressions, self:parseExpr(0))
		-- Next should be InterpStringMid / InterpStringEnd; loop continues.
		local nt = self:current().type
		if nt ~= T.InterpStringBegin and nt ~= T.InterpStringMid and nt ~= T.InterpStringEnd then
			error("Malformed interpolated string at line " .. tostring(endLoc.begin.line + 1))
		end
	end

	return {
		kind = "expr",
		tag = "interpolatedstring",
		location = spanOf(start.begin, endLoc.endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = copyPos(endLoc.endPos),
		strings = strings,
		expressions = expressions,
	}
end

function Parser.tableSeparatorText(self): string?
	local t = self:current().type
	if t == 44 then
		return ","
	elseif t == 59 then
		return ";"
	end
	return nil
end

function Parser.parseTableConstructor(self): any
	local start = self:current().location
	local openToken = self:tok(start.begin, "{")
	self:expectAndConsume(123) -- '{'

	local entries = {}

	while self:current().type ~= 125 do -- '}'
		local item: any
		if self:current().type == 91 then -- '['
			local indexerOpenBegin = copyPos(self:current().location.begin)
			self:nextLexeme()
			local key = self:parseExpr(0)
			local closeBegin = copyPos(self:current().location.begin)
			local closeFound = self:current().type == 93
			self:expectAndConsume(93) -- ']'
			local equalsBegin = copyPos(self:current().location.begin)
			local equalsFound = self:current().type == 61
			self:expectAndConsume(61) -- '='
			local value = self:parseExpr(0)
			item = {
				kind = "general",
				isTableItem = true,
				location = spanOf(indexerOpenBegin, value._locEnd),
				indexerOpen = self:tok(indexerOpenBegin, "["),
				key = key,
				indexerClose = if closeFound then self:tok(closeBegin, "]") else nil,
				equals = if equalsFound then self:tok(equalsBegin, "=") else nil,
				value = value,
			}
		elseif self:current().type == T.Name and self:lookahead().type == 61 then
			local name = self:parseName()
			local equalsBegin = copyPos(self:current().location.begin)
			self:expectAndConsume(61) -- '='
			local value = self:parseExpr(0)
			item = {
				kind = "record",
				isTableItem = true,
				location = spanOf(name.location.begin, value._locEnd),
				key = self:tok(name.location.begin, name.name),
				equals = self:tok(equalsBegin, "="),
				value = value,
			}
		else
			local value = self:parseExpr(0)
			item = {
				kind = "list",
				isTableItem = true,
				location = spanOf(value._locBegin, value._locEnd),
				value = value,
			}
		end

		-- Separator handling (comma/semicolon) belongs to the item.
		local sepText = self:tableSeparatorText()
		if sepText then
			item.separator = self:tok(self:current().location.begin, sepText)
		else
			item.separator = nil
		end

		table.insert(entries, item)

		local ct = self:current().type
		if ct == 44 or ct == 59 then -- ',' ';'
			self:nextLexeme()
		elseif ct == 91 or ct == T.Name then
			-- missing separator (reported in Luau); keep going
		elseif ct ~= 125 then
			break
		end
	end

	local endLoc = self:current().location
	local closeFound = self:current().type == 125
	local endPos: Position
	if closeFound then
		endPos = copyPos(endLoc.endPos)
		self:nextLexeme()
	else
		endPos = copyPos(self.lexer.prevLocation.endPos)
	end

	return {
		kind = "expr",
		tag = "table",
		location = spanOf(start.begin, endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = endPos,
		openBrace = openToken,
		entries = entries,
		closeBrace = self:tok({ line = endPos.line, column = endPos.column - 1 }, "}"),
	}
end

-- ===== Type annotations =====

function Parser.prevEnd(self): Position
	return copyPos(self.lexer.prevLocation.endPos)
end

function Parser.prevBegin(self): Position
	return copyPos(self.lexer.prevLocation.begin)
end

local function isTypeFollow(ty: number): boolean
	return ty == 124 or ty == 63 or ty == 38 -- '|' '?' '&'
end

function Parser.shouldParseTypePack(self): boolean
	local t = self:current().type
	if t == T.Dot3 then
		return true
	elseif t == T.Name and self:lookahead().type == T.Dot3 then
		return true
	end
	return false
end

function Parser.parseTypePack(self): any
	if self:current().type == T.Dot3 then -- '...T'
		local start = self:current().location
		local ellipsisBegin = copyPos(start.begin)
		self:nextLexeme()
		local ty = self:parseType()
		return {
			kind = "typepack",
			tag = "variadic",
			location = spanOf(start.begin, ty._locEnd),
			_locBegin = copyPos(start.begin),
			_locEnd = ty._locEnd,
			ellipsis = self:tok(ellipsisBegin, "..."),
			type = ty,
		}
	else -- 'a...'
		local name = self:parseName()
		local endLoc = self:current().location
		local ellipsisBegin = copyPos(endLoc.begin)
		self:expectAndConsume(T.Dot3)
		return {
			kind = "typepack",
			tag = "generic",
			location = spanOf(name.location.begin, endLoc.endPos),
			_locBegin = copyPos(name.location.begin),
			_locEnd = copyPos(endLoc.endPos),
			name = self:tok(name.location.begin, name.name),
			ellipsis = self:tok(ellipsisBegin, "..."),
		}
	end
end

-- Returns a variadic/generic type pack for `...` function vararg annotations.
function Parser.parseVariadicArgumentTypePack(self): any
	if self:current().type == T.Name and self:lookahead().type == T.Dot3 then
		local name = self:parseName()
		local endLoc = self:current().location
		local ellipsisBegin = copyPos(endLoc.begin)
		self:expectAndConsume(T.Dot3)
		return {
			kind = "typepack",
			tag = "generic",
			location = spanOf(name.location.begin, endLoc.endPos),
			_locBegin = copyPos(name.location.begin),
			_locEnd = copyPos(endLoc.endPos),
			name = self:tok(name.location.begin, name.name),
			ellipsis = self:tok(ellipsisBegin, "..."),
		}
	else
		local ty = self:parseType()
		-- variadic without leading '...' (used as function vararg annotation)
		return {
			kind = "typepack",
			tag = "variadic",
			location = ty.location,
			_locBegin = ty._locBegin,
			_locEnd = ty._locEnd,
			ellipsis = nil,
			type = ty,
			_forVararg = true,
		}
	end
end

-- Parses a comma-separated list of (optionally named) types; returns a tail
-- type pack (or nil) plus fills result/names/commaPositions/nameColonPositions.
function Parser.parseTypeList(self, result: { any }, resultNames: { any }, commaPositions: { Position }, nameColonPositions: { Position? }): any?
	while true do
		if self:shouldParseTypePack() then
			return self:parseTypePack()
		end

		if self:current().type == T.Name and self:lookahead().type == 58 then -- Name ':'
			while #resultNames < #result do
				table.insert(resultNames, false)
			end
			while #nameColonPositions < #result do
				table.insert(nameColonPositions, false)
			end
			local nameLoc = self:current().location
			table.insert(resultNames, { name = self:current().data, location = nameLoc })
			self:nextLexeme()
			table.insert(nameColonPositions, copyPos(self:current().location.begin))
			self:expectAndConsume(58) -- ':'
		elseif #resultNames > 0 then
			table.insert(resultNames, false)
			table.insert(nameColonPositions, false)
		end

		table.insert(result, self:parseType())
		if self:current().type ~= 44 then
			break
		end
		table.insert(commaPositions, copyPos(self:current().location.begin))
		self:nextLexeme()
		if self:current().type == 41 then -- ')'
			break
		end
	end
	return nil
end

function Parser.parseReturnType(self): any
	local begin = self:current().location

	if self:current().type ~= 40 then -- not '('
		if self:shouldParseTypePack() then
			return self:parseTypePack()
		end
		local ty = self:parseType()
		return {
			kind = "typepack",
			tag = "explicit",
			location = ty.location,
			_locBegin = ty._locBegin,
			_locEnd = ty._locEnd,
			openParens = nil,
			types = self:punctuated({ ty }, {}, ","),
			tailType = nil,
			closeParens = nil,
		}
	end

	self:nextLexeme() -- '('
	local result = {}
	local resultNames = {}
	local commaPositions = {}
	local nameColonPositions = {}
	local varargAnnotation: any = nil
	if self:current().type ~= 41 then
		varargAnnotation = self:parseTypeList(result, resultNames, commaPositions, nameColonPositions)
	end

	local locBegin = copyPos(begin.begin)
	local closeLoc = self:current().location
	local closeFound = self:current().type == 41
	self:expectAndConsume(41) -- ')'
	local closeParenPos: Position? = if closeFound then self:prevBegin() else nil
	local locEnd = copyPos(closeLoc.endPos)

	if self:current().type ~= T.SkinnyArrow and #resultNames == 0 then
		if #result == 1 then
			local inner: any
			local parensBelongToInnerGroup = false
			if varargAnnotation == nil and isTypeFollow(self:current().type) then
				inner = {
					kind = "type",
					tag = "group",
					location = spanOf(locBegin, locEnd),
					_locBegin = locBegin,
					_locEnd = locEnd,
					openParens = self:tok(locBegin, "("),
					type = result[1],
					closeParens = if closeFound then self:tok(closeParenPos :: Position, ")") else nil,
				}
				parensBelongToInnerGroup = true
			else
				inner = result[1]
			end

			local returnType = self:parseTypeSuffix(inner, begin)
			local endPos = if #result == 1 then locEnd else returnType._locEnd
			local node: any = {
				kind = "typepack",
				tag = "explicit",
				location = spanOf(locBegin, endPos),
				_locBegin = locBegin,
				_locEnd = endPos,
			}
			if parensBelongToInnerGroup then
				node.openParens = nil
				node.types = self:punctuated({ returnType }, {}, ",")
				node.tailType = varargAnnotation
				node.closeParens = nil
			else
				node.openParens = self:tok(locBegin, "(")
				node.types = self:punctuated({ returnType }, commaPositions, ",")
				node.tailType = varargAnnotation
				node.closeParens = if closeFound then self:tok(closeParenPos :: Position, ")") else nil
			end
			return node
		end

		return {
			kind = "typepack",
			tag = "explicit",
			location = spanOf(locBegin, locEnd),
			_locBegin = locBegin,
			_locEnd = locEnd,
			openParens = self:tok(locBegin, "("),
			types = self:punctuated(result, commaPositions, ","),
			tailType = varargAnnotation,
			closeParens = if closeFound then self:tok(closeParenPos :: Position, ")") else nil,
		}
	end

	local returnArrowPos = copyPos(self:current().location.begin)
	local tail = self:parseFunctionTypeTail(begin, {}, {}, {}, result, resultNames, varargAnnotation, {
		openGenericsPos = nil,
		genericsCommaPositions = {},
		closeGenericsPos = nil,
		openArgsPos = locBegin,
		argumentNameColonPositions = nameColonPositions,
		argumentsCommaPositions = commaPositions,
		closeArgsPos = closeParenPos,
		returnArrowPos = returnArrowPos,
	})
	return {
		kind = "typepack",
		tag = "explicit",
		location = spanOf(locBegin, tail._locEnd),
		_locBegin = locBegin,
		_locEnd = tail._locEnd,
		openParens = nil,
		types = self:punctuated({ tail }, {}, ","),
		tailType = nil,
		closeParens = nil,
	}
end

function Parser.parseTypeSuffix(self, ty: any, begin: lexermod.Location): any
	local parts = {}
	local separatorPositions = {}
	local leadingPos: Position? = nil
	if ty ~= nil then
		table.insert(parts, ty)
	end

	local isUnion = false
	local isIntersection = false
	local locEnd: Position

	while true do
		local c = self:current().type
		local sepBegin = copyPos(self:current().location.begin)
		if c == 124 then -- '|'
			self:nextLexeme()
			table.insert(parts, self:parseSimpleType(false).type)
			isUnion = true
			if ty == nil and leadingPos == nil then
				leadingPos = sepBegin
			else
				table.insert(separatorPositions, sepBegin)
			end
		elseif c == 63 then -- '?'
			local loc = self:current().location
			self:nextLexeme()
			table.insert(parts, {
				_optional = true,
				location = spanOf(loc.begin, loc.endPos),
				_locBegin = copyPos(loc.begin),
				_locEnd = copyPos(loc.endPos),
			})
			isUnion = true
		elseif c == 38 then -- '&'
			self:nextLexeme()
			table.insert(parts, self:parseSimpleType(false).type)
			isIntersection = true
			if ty == nil and leadingPos == nil then
				leadingPos = sepBegin
			else
				table.insert(separatorPositions, sepBegin)
			end
		else
			break
		end
	end

	if #parts == 1 and not isUnion and not isIntersection then
		return parts[1]
	end

	locEnd = parts[#parts]._locEnd
	local locBegin = copyPos(begin.begin)

	if isUnion then
		-- Custom punctuated: separators are a sparse array parallel to the type
		-- list (optional `?` types do not consume a separator slot).
		local out = {}
		local separators = {}
		local sepIdx = 1
		for i, part in parts do
			if part._optional then
				out[i] = {
					kind = "type",
					tag = "optional",
					location = part.location,
					token = self:tok(part._locBegin, "?"),
				}
				if i < #parts and sepIdx <= #separatorPositions then
					separators[i] = self:tok(separatorPositions[sepIdx], "|")
					sepIdx += 1
				end
			else
				out[i] = part
				if i < #parts and not parts[i + 1]._optional and sepIdx <= #separatorPositions then
					separators[i] = self:tok(separatorPositions[sepIdx], "|")
					sepIdx += 1
				end
			end
		end
		out.separators = separators
		return {
			kind = "type",
			tag = "union",
			location = spanOf(locBegin, locEnd),
			_locBegin = locBegin,
			_locEnd = locEnd,
			leading = if leadingPos then self:tok(leadingPos, "|") else nil,
			types = out,
		}
	end

	-- intersection
	return {
		kind = "type",
		tag = "intersection",
		location = spanOf(locBegin, locEnd),
		_locBegin = locBegin,
		_locEnd = locEnd,
		leading = if leadingPos then self:tok(leadingPos, "&") else nil,
		types = self:punctuated(parts, separatorPositions, "&"),
	}
end

function Parser.parseType(self, inDeclarationContext: boolean?): any
	local begin = self:current().location
	local ty: any = nil
	local c = self:current().type
	if c ~= 124 and c ~= 38 then
		ty = self:parseSimpleType(false, inDeclarationContext).type
	end
	return self:parseTypeSuffix(ty, begin)
end

function Parser.parseSimpleTypeOrPack(self): any
	local begin = self:current().location
	local r = self:parseSimpleType(true)
	if r.typePack then
		return { type = nil, typePack = r.typePack }
	end
	return { type = self:parseTypeSuffix(r.type, begin), typePack = nil }
end

function Parser.parseSimpleType(self, allowPack: boolean, inDeclarationContext: boolean?): any
	local start = self:current().location
	local ty = self:current().type

	if ty == T.ReservedNil then
		self:nextLexeme()
		return { type = {
			kind = "type",
			tag = "reference",
			location = spanOf(start.begin, start.endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = copyPos(start.endPos),
			name = self:tok(start.begin, "nil"),
		} }
	elseif ty == T.ReservedTrue or ty == T.ReservedFalse then
		local value = ty == T.ReservedTrue
		self:nextLexeme()
		return { type = {
			kind = "type",
			tag = "boolean",
			location = spanOf(start.begin, start.endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = copyPos(start.endPos),
			value = value,
			token = self:tok(start.begin, if value then "true" else "false"),
		} }
	elseif ty == T.RawString or ty == T.QuotedString then
		return { type = self:parseSingletonStringType(start) }
	elseif ty == T.Name then
		return { type = self:parseTypeReference(start) }
	elseif ty == 123 then -- '{'
		return { type = self:parseTableType(inDeclarationContext) }
	elseif ty == 40 or ty == 60 then -- '(' or '<'
		return self:parseFunctionType(allowPack, {})
	else
		error("parseSimpleType: unexpected token at line " .. tostring(start.begin.line + 1))
	end
end

function Parser.parseSingletonStringType(self, start: lexermod.Location): any
	local cur = self:current()
	local data = cur.data :: string
	local quoteStyle: string
	if cur.type == T.QuotedString then
		local q = self:byteAtPos(cur.location.begin)
		quoteStyle = if q == 34 then "double" else "single"
	else
		quoteStyle = "double"
	end
	self:nextLexeme()
	local tokPlaceholder = self:tok(start.begin, data)
	tokPlaceholder._forceEnd = copyPos(start.endPos)
	return {
		kind = "type",
		tag = "string",
		location = spanOf(start.begin, start.endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = copyPos(start.endPos),
		quoteStyle = quoteStyle,
		value = tokPlaceholder,
	}
end

function Parser.parseTypeReference(self, start: lexermod.Location): any
	local prefixTok: any = nil
	local prefixPointTok: any = nil
	local name = self:parseName()

	if self:current().type == 46 then -- '.'
		local pointBegin = copyPos(self:current().location.begin)
		self:nextLexeme()
		prefixTok = self:tok(name.location.begin, name.name)
		prefixPointTok = self:tok(pointBegin, ".")
		name = self:parseIndexName(pointBegin)
	elseif name.name == "typeof" then
		local typeofBegin = copyPos(start.begin)
		local openFound = self:current().type == 40
		local openBegin = copyPos(self:current().location.begin)
		self:expectAndConsume(40) -- '('
		local expr = self:parseExpr(0)
		local endLoc = self:current().location
		local closeFound = self:current().type == 41
		local closeBegin = copyPos(endLoc.begin)
		self:expectAndConsume(41) -- ')'
		return {
			kind = "type",
			tag = "typeof",
			location = spanOf(start.begin, endLoc.endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = copyPos(endLoc.endPos),
			typeof = self:tok(typeofBegin, "typeof"),
			openParens = self:tok(openBegin, "("),
			expression = expr,
			closeParens = self:tok(closeBegin, ")"),
		}
	end

	local hasParameters = false
	local openParamsTok, closeParamsTok, parameters
	if self:current().type == 60 then -- '<'
		hasParameters = true
		local tp = self:parseTypeParams()
		openParamsTok = self:tok(tp.openPos :: Position, "<")
		parameters = self:punctuated(tp.params, tp.commaPositions, ",")
		closeParamsTok = if tp.closePos then self:tok(tp.closePos, ">") else self:tok(tp.closePos :: Position, ">")
	end

	local endPos = self:prevEnd()
	local node: any = {
		kind = "type",
		tag = "reference",
		location = spanOf(start.begin, endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = endPos,
		name = self:tok(name.location.begin, name.name),
	}
	if prefixTok then
		node.prefix = prefixTok
		node.prefixPoint = prefixPointTok
	end
	if hasParameters then
		node.openParameters = openParamsTok
		node.parameters = parameters
		node.closeParameters = closeParamsTok
	end
	return node
end

function Parser.parseTypeParams(self): any
	local params = {}
	local commaPositions = {}
	local openPos: Position? = nil
	local closePos: Position? = nil
	if self:current().type == 60 then -- '<'
		openPos = copyPos(self:current().location.begin)
		self:nextLexeme()
		while true do
			if self:shouldParseTypePack() then
				table.insert(params, self:parseTypePack())
			elseif self:current().type == 40 then -- '('
				local begin = self:current().location
				local r = self:parseSimpleType(true, false)
				if r.typePack then
					local etp = r.typePack
					if etp.tag == "explicit" and etp.tailType == nil and #etp.types == 1 and isTypeFollow(self:current().type) then
						local parenthesized = etp.types[1]
						local typeGroup = {
							kind = "type",
							tag = "group",
							location = parenthesized.location,
							_locBegin = parenthesized._locBegin,
							_locEnd = parenthesized._locEnd,
							openParens = etp.openParens,
							type = parenthesized,
							closeParens = etp.closeParens,
						}
						table.insert(params, self:parseTypeSuffix(typeGroup, begin))
					else
						table.insert(params, etp)
					end
				else
					table.insert(params, self:parseTypeSuffix(r.type, begin))
				end
			elseif self:current().type == 62 and #params == 0 then -- '>'
				break
			else
				table.insert(params, self:parseType())
			end

			if self:current().type == 44 then
				table.insert(commaPositions, copyPos(self:current().location.begin))
				self:nextLexeme()
			else
				break
			end
		end
		local closeFound = self:current().type == 62
		self:expectAndConsume(62) -- '>'
		if closeFound then
			closePos = self:prevBegin()
		end
	end
	return { params = params, commaPositions = commaPositions, openPos = openPos, closePos = closePos }
end

function Parser.parseTableIndexer(self, access: string?, accessTok: any, beginLoc: lexermod.Location): any
	local index = self:parseType()
	local closeFound = self:current().type == 93
	local closeBegin = copyPos(self:current().location.begin)
	self:expectAndConsume(93) -- ']'
	local colonFound = self:current().type == 58
	local colonBegin = copyPos(self:current().location.begin)
	self:expectAndConsume(58) -- ':'
	local result = self:parseType()
	return {
		node = { index = index, result = result },
		indexerOpenBegin = copyPos(beginLoc.begin),
		_closeFound = closeFound,
		_closeBegin = closeBegin,
		_colonFound = colonFound,
		_colonBegin = colonBegin,
	}
end

function Parser.parseTableType(self, inDeclarationContext: boolean?): any
	local start = self:current().location
	local openTok = self:tok(start.begin, "{")
	self:expectAndConsume(123) -- '{'

	local entries = {}
	local isArray = false
	local arrayAccessTok: any = nil
	local arrayType: any = nil

	while self:current().type ~= 125 do -- '}'
		local access: string? = nil
		local accessTok: any = nil
		if self:current().type == T.Name and self:lookahead().type ~= 58 then
			local nm = self:current().data
			if nm == "read" or nm == "write" then
				access = nm
				accessTok = self:tok(self:current().location.begin, nm)
				self.lexer:next() -- raw next (matches Luau's lexer.next())
			end
		end

		if self:current().type == 91 then -- '['
			local beginLoc = self:current().location
			self:nextLexeme()
			if (self:current().type == T.RawString or self:current().type == T.QuotedString) and self:lookahead().type == 93 then
				-- string property
				local strLoc = self:current().location
				local strData = self:current().data
				local q = if self:current().type == T.QuotedString then (if self:byteAtPos(strLoc.begin) == 34 then "double" else "single") else "double"
				self:nextLexeme()
				local closeFound = self:current().type == 93
				local closeBegin = copyPos(self:current().location.begin)
				self:expectAndConsume(93)
				local colonFound = self:current().type == 58
				local colonBegin = copyPos(self:current().location.begin)
				self:expectAndConsume(58)
				local ty = self:parseType()
				local keyTok = self:tok(strLoc.begin, strData)
				keyTok._forceEnd = copyPos(strLoc.endPos)
				local item: any = {
					kind = "property",
					access = accessTok,
					indexerOpen = self:tok(beginLoc.begin, "["),
					quoteStyle = q,
					key = keyTok,
					indexerClose = if closeFound then self:tok(closeBegin, "]") else nil,
					colon = if colonFound then self:tok(colonBegin, ":") else nil,
					value = ty,
				}
				self:attachTableSeparator(item)
				table.insert(entries, item)
			else
				-- indexer
				local idx = self:parseTableIndexer(access, accessTok, beginLoc)
				local item: any = {
					kind = "indexer",
					access = accessTok,
					indexerOpen = self:tok(idx.indexerOpenBegin, "["),
					key = idx.node.index,
					indexerClose = if idx._closeFound then self:tok(idx._closeBegin, "]") else nil,
					colon = if idx._colonFound then self:tok(idx._colonBegin, ":") else nil,
					value = idx.node.result,
				}
				self:attachTableSeparator(item)
				table.insert(entries, item)
			end
		elseif #entries == 0 and not (self:current().type == T.Name and self:lookahead().type == 58) then
			-- array-like {T}
			local ty = self:parseType()
			isArray = true
			arrayAccessTok = accessTok
			arrayType = ty
			break
		else
			local name = self:parseNameOpt()
			if not name then
				break
			end
			local colonFound = self:current().type == 58
			local colonBegin = copyPos(self:current().location.begin)
			self:expectAndConsume(58)
			local ty = self:parseType(inDeclarationContext)
			local item: any = {
				kind = "property",
				access = accessTok,
				indexerOpen = nil,
				quoteStyle = nil,
				key = self:tok(name.location.begin, name.name),
				indexerClose = nil,
				colon = if colonFound then self:tok(colonBegin, ":") else nil,
				value = ty,
			}
			self:attachTableSeparator(item)
			table.insert(entries, item)
		end

		if self:current().type == 44 or self:current().type == 59 then
			self:nextLexeme()
		else
			if self:current().type ~= 125 then
				break
			end
		end
	end

	local endLoc = self:current().location
	local closeFound = self:current().type == 125
	local endPos: Position
	if closeFound then
		endPos = copyPos(endLoc.endPos)
		self:nextLexeme()
	else
		endPos = self:prevEnd()
	end

	if isArray then
		return {
			kind = "type",
			tag = "array",
			location = spanOf(start.begin, endPos),
			_locBegin = copyPos(start.begin),
			_locEnd = endPos,
			openBrace = openTok,
			access = arrayAccessTok,
			type = arrayType,
			closeBrace = self:tok({ line = endPos.line, column = endPos.column - 1 }, "}"),
		}
	end

	return {
		kind = "type",
		tag = "table",
		location = spanOf(start.begin, endPos),
		_locBegin = copyPos(start.begin),
		_locEnd = endPos,
		openBrace = openTok,
		entries = entries,
		closeBrace = self:tok({ line = endPos.line, column = endPos.column - 1 }, "}"),
	}
end

-- Attaches a trailing separator token (',' or ';') to a table-type item.
function Parser.attachTableSeparator(self, item: any)
	local t = self:current().type
	if t == 44 then
		item.separator = self:tok(self:current().location.begin, ",")
	elseif t == 59 then
		item.separator = self:tok(self:current().location.begin, ";")
	else
		item.separator = nil
	end
end

function Parser.parseFunctionType(self, allowPack: boolean, attributes: { any }): any
	local forceFunctionType = self:current().type == 60 -- '<'
	local begin = self:current().location

	local gen = self:parseGenericTypeList(false)

	local parameterStart = self:current().location
	local openArgsFound = self:current().type == 40
	self:expectAndConsume(40) -- '('

	local params = {}
	local names = {}
	local nameColonPositions = {}
	local argCommaPositions = {}
	local varargAnnotation: any = nil
	if self:current().type ~= 41 then
		varargAnnotation = self:parseTypeList(params, names, argCommaPositions, nameColonPositions)
	end

	local closeArgsLoc = self:current().location
	local closeArgsFound = self:current().type == 41
	self:expectAndConsume(41) -- ')'

	if #names > 0 then
		forceFunctionType = true
	end
	local returnTypeIntroducer = self:current().type == T.SkinnyArrow or self:current().type == 58

	if #params == 1 and not varargAnnotation and not forceFunctionType and not returnTypeIntroducer then
		if allowPack then
			return { type = nil, typePack = {
				kind = "typepack",
				tag = "explicit",
				location = spanOf(begin.begin, begin.endPos),
				_locBegin = copyPos(begin.begin),
				_locEnd = copyPos(begin.endPos),
				openParens = if openArgsFound then self:tok(parameterStart.begin, "(") else nil,
				types = self:punctuated(params, argCommaPositions, ","),
				tailType = nil,
				closeParens = if closeArgsFound then self:tok(closeArgsLoc.begin, ")") else nil,
			} }
		else
			return { type = {
				kind = "type",
				tag = "group",
				location = spanOf(parameterStart.begin, closeArgsLoc.endPos),
				_locBegin = copyPos(parameterStart.begin),
				_locEnd = copyPos(closeArgsLoc.endPos),
				openParens = self:tok(parameterStart.begin, "("),
				type = params[1],
				closeParens = if closeArgsFound then self:tok(closeArgsLoc.begin, ")") else nil,
			} }
		end
	end

	if not forceFunctionType and not returnTypeIntroducer and allowPack then
		return { type = nil, typePack = {
			kind = "typepack",
			tag = "explicit",
			location = spanOf(begin.begin, begin.endPos),
			_locBegin = copyPos(begin.begin),
			_locEnd = copyPos(begin.endPos),
			openParens = if openArgsFound then self:tok(parameterStart.begin, "(") else nil,
			types = self:punctuated(params, argCommaPositions, ","),
			tailType = varargAnnotation,
			closeParens = if closeArgsFound then self:tok(closeArgsLoc.begin, ")") else nil,
		} }
	end

	local returnArrowPos = copyPos(self:current().location.begin)
	local node = self:parseFunctionTypeTail(begin, attributes, gen.generics, gen.genericPacks, params, names, varargAnnotation, {
		openGenericsPos = gen.openPos,
		genericsCommaPositions = gen.commaPositions,
		closeGenericsPos = gen.closePos,
		openArgsPos = if openArgsFound then copyPos(parameterStart.begin) else nil,
		argumentNameColonPositions = nameColonPositions,
		argumentsCommaPositions = argCommaPositions,
		closeArgsPos = if closeArgsFound then copyPos(closeArgsLoc.begin) else nil,
		returnArrowPos = returnArrowPos,
	})
	return { type = node, typePack = nil }
end

function Parser.parseFunctionTypeTail(self, begin: lexermod.Location, attributes, generics, genericPacks, params, paramNames, varargAnnotation, cst): any
	if self:current().type == 58 then -- ':'
		self:nextLexeme()
	elseif self:current().type ~= T.SkinnyArrow and #generics == 0 and #genericPacks == 0 and #params == 0 then
		-- '()' with no arrow: Luau treats as 'nil' reference (error reported)
		return {
			kind = "type",
			tag = "reference",
			location = spanOf(begin.begin, begin.endPos),
			_locBegin = copyPos(begin.begin),
			_locEnd = copyPos(begin.endPos),
			name = self:tok(begin.begin, "nil"),
		}
	else
		self:expectAndConsume(T.SkinnyArrow)
	end

	local returnType = self:parseReturnType()

	-- Build CstFunctionTypeParameter punctuated for parameters.
	local out = {}
	local separators = {}
	for i, p in params do
		local argName = paramNames[i]
		local param: any = { type = p }
		if argName and argName ~= false then
			param.name = self:tok(argName.location.begin, argName.name)
		else
			param.name = nil
		end
		local colonPos = cst.argumentNameColonPositions[i]
		if colonPos then
			param.colon = self:tok(colonPos, ":")
		else
			param.colon = nil
		end
		out[i] = param
		if i <= #cst.argumentsCommaPositions then
			table.insert(separators, self:tok(cst.argumentsCommaPositions[i], ","))
		end
	end
	out.separators = separators

	local node: any = {
		kind = "type",
		tag = "function",
		location = spanOf(begin.begin, returnType._locEnd),
		_locBegin = copyPos(begin.begin),
		_locEnd = returnType._locEnd,
	}
	if #generics > 0 or #genericPacks > 0 then
		node.openGenerics = self:tok(cst.openGenericsPos :: Position, "<")
		node.generics = self:punctuated(generics, cst.genericsCommaPositions, ",")
		node.genericPacks = self:punctuated(genericPacks, splitArray(cst.genericsCommaPositions, #generics), ",")
		node.closeGenerics = self:tok(cst.closeGenericsPos :: Position, ">")
	end
	node.openParens = self:tok(cst.openArgsPos :: Position, "(")
	node.parameters = out
	node.vararg = varargAnnotation
	node.closeParens = self:tok(cst.closeArgsPos :: Position, ")")
	node.returnArrow = self:tok(cst.returnArrowPos, "->")
	node.returnTypes = returnType
	return node
end

-- ===== Finalization =====

function Parser.finalize(self, rootExprMode: boolean, root: any): any
	-- Fill token placeholders in source (= emission) order.
	table.sort(self.tokens, function(a, b)
		local pa, pb = a._pos, b._pos
		if pa.line == pb.line then
			return pa.column < pb.column
		end
		return pa.line < pb.line
	end)

	local builder = buildermod.new(self.source, self.comments)
	for _, tok in self.tokens do
		builder:fill(tok)
	end
	return builder
end

-- Recursively removes internal helper fields (keys beginning with "_") from the
-- produced tree so it compares cleanly against the native CST.
local function cleanTree(root: any)
	local seen = {}
	local function visit(t: any)
		if type(t) ~= "table" or seen[t] then
			return
		end
		seen[t] = true
		local toDelete = {}
		local k = next(t)
		while k ~= nil do
			if type(k) == "string" and string.sub(k, 1, 1) == "_" then
				table.insert(toDelete, k)
			else
				visit(t[k])
			end
			k = next(t, k)
		end
		for _, key in toDelete do
			t[key] = nil
		end
	end
	visit(root)
end

-- ===== Public API =====

local function parse(source: string): any
	local self = new(source)
	local root = self:parseChunk()

	-- lines computation (matches Luau: eof end line + trailing-non-newline)
	local eofEndLine = self.lexer.lexeme.location.endPos.line
	local lastByte = if #source > 0 then string.byte(source, #source) else nil
	local lines = eofEndLine + (if #source > 0 and lastByte ~= 10 then 1 else 0)

	-- eof token placeholder at root end.
	local eofPos = copyPos(root._locEnd)
	local eofTok = self:tok(eofPos, "")

	self:finalize(false, root)

	eofTok.tag = "eof"

	-- lineOffsets (1-based values).
	local rawOffsets = buildermod.computeLineOffsets(source)
	local lineOffsets = {}
	for i, off in rawOffsets do
		lineOffsets[i] = off + 1
	end

	-- Strip internal underscore-prefixed helper fields from the tree.
	cleanTree(root)

	return {
		root = root,
		eof = eofTok,
		lines = lines,
		lineOffsets = lineOffsets,
	}
end

local function parseExpr(source: string): any
	local self = new(source)
	local expr = self:parseExpr(0)
	self:finalize(true, expr)
	cleanTree(expr)
	return expr
end

return {
	parse = parse,
	parseExpr = parseExpr,
}
