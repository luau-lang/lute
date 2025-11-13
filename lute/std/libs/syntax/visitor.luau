--!strict
-- @std/syntax/visitor
-- Visitor pattern implementation for traversing Luau AST nodes

local types = require("./types")

local visitorlib = {}

export type Visitor = {
	visitBlock: (types.AstStatBlock) -> boolean,
	visitBlockEnd: (types.AstStatBlock) -> (),
	visitIf: (types.AstStatIf) -> boolean,
	visitWhile: (types.AstStatWhile) -> boolean,
	visitRepeat: (types.AstStatRepeat) -> boolean,
	visitReturn: (types.AstStatReturn) -> boolean,
	visitLocalDeclaration: (types.AstStatLocal) -> boolean,
	visitLocalDeclarationEnd: (types.AstStatLocal) -> (),
	visitFor: (types.AstStatFor) -> boolean,
	visitForIn: (types.AstStatForIn) -> boolean,
	visitAssign: (types.AstStatAssign) -> boolean,
	visitCompoundAssign: (types.AstStatCompoundAssign) -> boolean,
	visitFunction: (types.AstStatFunction) -> boolean,
	visitLocalFunction: (types.AstStatLocalFunction) -> boolean,
	visitTypeAlias: (types.AstStatTypeAlias) -> boolean,
	visitStatTypeFunction: (types.AstStatTypeFunction) -> boolean,

	visitExpression: (types.AstExpr) -> boolean,
	visitExpressionEnd: (types.AstExpr) -> (),
	visitLocalReference: (types.AstExprLocal) -> boolean,
	visitGlobal: (types.AstExprGlobal) -> boolean,
	visitCall: (types.AstExprCall) -> boolean,
	visitUnary: (types.AstExprUnary) -> boolean,
	visitBinary: (types.AstExprBinary) -> boolean,
	visitAnonymousFunction: (types.AstExprAnonymousFunction) -> boolean,
	visitTableItem: (types.AstExprTableItem) -> boolean,
	visitTable: (types.AstExprTable) -> boolean,
	visitIndexName: (types.AstExprIndexName) -> boolean,
	visitIndexExpr: (types.AstExprIndexExpr) -> boolean,
	visitGroup: (types.AstExprGroup) -> boolean,
	visitInterpolatedString: (types.AstExprInterpString) -> boolean,
	visitTypeAssertion: (types.AstExprTypeAssertion) -> boolean,
	visitIfExpression: (types.AstExprIfElse) -> boolean,

	visitTypeReference: (types.AstTypeReference) -> boolean,
	visitTypeBoolean: (types.AstTypeSingletonBool) -> boolean,
	visitTypeString: (types.AstTypeSingletonString) -> boolean,
	visitTypeTypeof: (types.AstTypeTypeof) -> boolean,
	visitTypeGroup: (types.AstTypeGroup) -> boolean,
	visitTypeUnion: (types.AstTypeUnion) -> boolean,
	visitTypeIntersection: (types.AstTypeIntersection) -> boolean,
	visitTypeArray: (types.AstTypeArray) -> boolean,
	visitTypeTable: (types.AstTypeTable) -> boolean,
	visitTypeFunction: (types.AstTypeFunction) -> boolean,

	visitTypePackExplicit: (types.AstTypePackExplicit) -> boolean,
	visitTypePackGeneric: (types.AstTypePackGeneric) -> boolean,
	visitTypePackVariadic: (types.AstTypePackVariadic) -> boolean,

	visitToken: (types.Token) -> boolean,
	visitNil: (types.AstExprConstantNil) -> boolean,
	visitString: (types.AstExprConstantString) -> boolean,
	visitBoolean: (types.AstExprConstantBool) -> boolean,
	visitNumber: (types.AstExprConstantNumber) -> boolean,
	visitLocal: (types.AstLocal) -> boolean,
	visitVarargs: (types.AstExprVarargs) -> boolean,
}

local function alwaysVisit(...: any)
	return true
end

local defaultVisitor: Visitor = {
	visitBlock = alwaysVisit :: any,
	visitBlockEnd = alwaysVisit :: any,
	visitIf = alwaysVisit :: any,
	visitWhile = alwaysVisit :: any,
	visitRepeat = alwaysVisit :: any,
	visitReturn = alwaysVisit :: any,
	visitLocalDeclaration = alwaysVisit :: any,
	visitLocalDeclarationEnd = alwaysVisit :: any,
	visitFor = alwaysVisit :: any,
	visitForIn = alwaysVisit :: any,
	visitAssign = alwaysVisit :: any,
	visitCompoundAssign = alwaysVisit :: any,
	visitFunction = alwaysVisit :: any,
	visitLocalFunction = alwaysVisit :: any,
	visitTypeAlias = alwaysVisit :: any,
	visitStatTypeFunction = alwaysVisit :: any,

	visitExpression = alwaysVisit :: any,
	visitExpressionEnd = alwaysVisit :: any,
	visitLocalReference = alwaysVisit :: any,
	visitGlobal = alwaysVisit :: any,
	visitCall = alwaysVisit :: any,
	visitUnary = alwaysVisit :: any,
	visitBinary = alwaysVisit :: any,
	visitAnonymousFunction = alwaysVisit :: any,
	visitTableItem = alwaysVisit :: any,
	visitTable = alwaysVisit :: any,
	visitIndexName = alwaysVisit :: any,
	visitIndexExpr = alwaysVisit :: any,
	visitGroup = alwaysVisit :: any,
	visitInterpolatedString = alwaysVisit,
	visitTypeAssertion = alwaysVisit,
	visitIfExpression = alwaysVisit,

	visitTypeReference = alwaysVisit :: any,
	visitTypeBoolean = alwaysVisit :: any,
	visitTypeString = alwaysVisit :: any,
	visitTypeTypeof = alwaysVisit :: any,
	visitTypeGroup = alwaysVisit :: any,
	visitTypeUnion = alwaysVisit :: any,
	visitTypeIntersection = alwaysVisit :: any,
	visitTypeArray = alwaysVisit :: any,
	visitTypeTable = alwaysVisit :: any,
	visitTypeFunction = alwaysVisit,

	visitTypePackExplicit = alwaysVisit,
	visitTypePackGeneric = alwaysVisit,
	visitTypePackVariadic = alwaysVisit,

	visitToken = alwaysVisit :: any,
	visitNil = alwaysVisit :: any,
	visitString = alwaysVisit :: any,
	visitBoolean = alwaysVisit :: any,
	visitNumber = alwaysVisit :: any,
	visitLocal = alwaysVisit :: any,
	visitVarargs = alwaysVisit :: any,
}

local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function visitToken<T>(token: types.Token<T>, visitor: Visitor)
	visitor.visitToken(token)
end

local function visitPunctuated<T, Separator>(list: types.Punctuated<T, Separator>, visitor: Visitor, apply: (T, Visitor) -> ())
	for _, item in list do
		apply(item.node, visitor)
		if item.separator then
			visitToken(item.separator, visitor)
		end
	end
end

local function visitLocal(node: types.AstLocal, visitor: Visitor)
	if visitor.visitLocal(node) then
		visitToken(node.name, visitor)
		if node.colon then
			visitToken(node.colon, visitor)
		end
		if node.annotation then
			visitType(node.annotation, visitor)
		end
	end
end

local function visitBlock(block: types.AstStatBlock, visitor: Visitor)
	if visitor.visitBlock(block) then
		for _, statement in block.statements do
			visitStatement(statement, visitor)
		end

		visitor.visitBlockEnd(block)
	end
end

local function visitIf(node: types.AstStatIf, visitor: Visitor)
	if visitor.visitIf(node) then
		visitToken(node.ifkeyword, visitor)
		visitExpression(node.condition, visitor)
		visitToken(node.thenkeyword, visitor)
		visitBlock(node.thenblock, visitor)
		for _, elseifNode in node.elseifs do
			visitToken(elseifNode.elseifkeyword, visitor)
			visitExpression(elseifNode.condition, visitor)
			visitToken(elseifNode.thenkeyword, visitor)
			visitBlock(elseifNode.thenblock, visitor)
		end
		if node.elsekeyword then
			visitToken(node.elsekeyword, visitor)
		end
		if node.elseblock then
			visitBlock(node.elseblock, visitor)
		end
		visitToken(node.endkeyword, visitor)
	end
end

local function visitWhile(node: types.AstStatWhile, visitor: Visitor)
	if visitor.visitWhile(node) then
		visitToken(node.whilekeyword, visitor)
		visitExpression(node.condition, visitor)
		visitToken(node.dokeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.endkeyword, visitor)
	end
end

local function visitRepeat(node: types.AstStatRepeat, visitor: Visitor)
	if visitor.visitRepeat(node) then
		visitToken(node.repeatKeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.untilKeyword, visitor)
		visitExpression(node.condition, visitor)
	end
end

local function visitReturn(node: types.AstStatReturn, visitor: Visitor)
	if visitor.visitReturn(node) then
		visitToken(node.returnkeyword, visitor)
		visitPunctuated(node.expressions, visitor, visitExpression)
	end
end

local function visitLocalStatement(node: types.AstStatLocal, visitor: Visitor)
	if visitor.visitLocalDeclaration(node) then
		visitToken(node.localkeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		if node.equals then
			visitToken(node.equals, visitor)
		end
		visitPunctuated(node.values, visitor, visitExpression)

		visitor.visitLocalDeclarationEnd(node)
	end
end

local function visitFor(node: types.AstStatFor, visitor: Visitor)
	if visitor.visitFor(node) then
		visitToken(node.forkeyword, visitor)
		visitLocal(node.variable, visitor)
		visitToken(node.equals, visitor)
		visitExpression(node.from, visitor)
		visitToken(node.tocomma, visitor)
		visitExpression(node.to, visitor)
		if node.stepcomma then
			visitToken(node.stepcomma, visitor)
		end
		if node.step then
			visitExpression(node.step, visitor)
		end
		visitToken(node.dokeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.endkeyword, visitor)
	end
end

local function visitForIn(node: types.AstStatForIn, visitor: Visitor)
	if visitor.visitForIn(node) then
		visitToken(node.forkeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		visitToken(node.inkeyword, visitor)
		visitPunctuated(node.values, visitor, visitExpression)
		visitToken(node.dokeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.endkeyword, visitor)
	end
end

local function visitAssign(node: types.AstStatAssign, visitor: Visitor)
	if visitor.visitAssign(node) then
		visitPunctuated(node.variables, visitor, visitExpression)
		visitToken(node.equals, visitor)
		visitPunctuated(node.values, visitor, visitExpression)
	end
end

local function visitCompoundAssign(node: types.AstStatCompoundAssign, visitor: Visitor)
	if visitor.visitCompoundAssign(node) then
		visitExpression(node.variable, visitor)
		visitToken(node.operand, visitor)
		visitExpression(node.value, visitor)
	end
end

local function visitGeneric(node: types.AstGenericType, visitor: Visitor)
	visitToken(node.name, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitType(node.default, visitor)
	end
end

local function visitGenericPack(node: types.AstGenericTypePack, visitor: Visitor)
	visitToken(node.name, visitor)
	visitToken(node.ellipsis, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitTypePack(node.default, visitor)
	end
end

local function visitTypeAlias(node: types.AstStatTypeAlias, visitor: Visitor)
	if visitor.visitTypeAlias(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.typeToken, visitor)
		visitToken(node.name, visitor)
		if node.opengenerics then
			visitToken(node.opengenerics, visitor)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric)
		end
		if node.genericpacks then
			visitPunctuated(node.genericpacks, visitor, visitGenericPack)
		end
		if node.closegenerics then
			visitToken(node.closegenerics, visitor)
		end
		visitToken(node.equals, visitor)
		visitType(node.type, visitor)
	end
end

local function visitString(node: types.AstExprConstantString, visitor: Visitor)
	if visitor.visitString(node) then
		visitor.visitToken(node)
	end
end

local function visitNil(node: types.AstExprConstantNil, visitor: Visitor)
	if visitor.visitNil(node) then
		visitToken(node, visitor)
	end
end

local function visitBoolean(node: types.AstExprConstantBool, visitor: Visitor)
	if visitor.visitBoolean(node) then
		visitToken(node, visitor)
	end
end

local function visitNumber(node: types.AstExprConstantNumber, visitor: Visitor)
	if visitor.visitNumber(node) then
		visitToken(node, visitor)
	end
end

local function visitLocalReference(node: types.AstExprLocal, visitor: Visitor)
	if visitor.visitLocalReference(node) then
		visitor.visitToken(node.token)
	end
end

local function visitGlobal(node: types.AstExprGlobal, visitor: Visitor)
	if visitor.visitGlobal(node) then
		visitor.visitToken(node.name)
	end
end

local function visitVarargs(node: types.AstExprVarargs, visitor: Visitor)
	if visitor.visitVarargs(node) then
		visitToken(node, visitor)
	end
end

local function visitCall(node: types.AstExprCall, visitor: Visitor)
	if visitor.visitCall(node) then
		visitExpression(node.func, visitor)
		if node.openparens then
			visitToken(node.openparens, visitor)
		end
		visitPunctuated(node.arguments, visitor, visitExpression)
		if node.closeparens then
			visitToken(node.closeparens, visitor)
		end
	end
end

local function visitUnary(node: types.AstExprUnary, visitor: Visitor)
	if visitor.visitUnary(node) then
		visitToken(node.operator, visitor)
		visitExpression(node.operand, visitor)
	end
end

local function visitBinary(node: types.AstExprBinary, visitor: Visitor)
	if visitor.visitBinary(node) then
		visitExpression(node.lhsoperand, visitor)
		visitToken(node.operator, visitor)
		visitExpression(node.rhsoperand, visitor)
	end
end

local function visitFunctionBody(node: types.AstFunctionBody, visitor: Visitor)
	if node.opengenerics then
		visitToken(node.opengenerics, visitor)
	end
	if node.generics then
		visitPunctuated(node.generics, visitor, visitGeneric)
	end
	if node.genericpacks then
		visitPunctuated(node.genericpacks, visitor, visitGenericPack)
	end
	if node.closegenerics then
		visitToken(node.closegenerics, visitor)
	end
	visitToken(node.openparens, visitor)
	visitPunctuated(node.parameters, visitor, visitLocal)
	if node.vararg then
		visitToken(node.vararg, visitor)
	end
	if node.varargcolon then
		visitToken(node.varargcolon, visitor)
	end
	if node.varargannotation then
		visitTypePack(node.varargannotation, visitor)
	end
	visitToken(node.closeparens, visitor)
	if node.returnspecifier then
		visitToken(node.returnspecifier, visitor)
	end
	if node.returnannotation then
		visitTypePack(node.returnannotation, visitor)
	end
	visitBlock(node.body, visitor)
	visitToken(node.endkeyword, visitor)
end

local function visitAttribute(node: types.AstAttribute, visitor)
	visitToken(node, visitor)
end

local function visitAnonymousFunction(node: types.AstExprAnonymousFunction, visitor: Visitor)
	if visitor.visitAnonymousFunction(node) then
		for _, attribute in node.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.functionkeyword, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitFunction(node: types.AstStatFunction, visitor: Visitor)
	if visitor.visitFunction(node) then
		for _, attribute in node.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.functionkeyword, visitor)
		visitExpression(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitLocalFunction(node: types.AstStatLocalFunction, visitor: Visitor)
	if visitor.visitLocalFunction(node) then
		for _, attribute in node.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.localkeyword, visitor)
		visitToken(node.functionkeyword, visitor)
		visitLocal(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitStatTypeFunction(node: types.AstStatTypeFunction, visitor: Visitor)
	if visitor.visitStatTypeFunction(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.type, visitor)
		visitToken(node.functionkeyword, visitor)
		visitToken(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitTableItem(node: types.AstExprTableItem, visitor: Visitor)
	if visitor.visitTableItem(node) then
		if node.kind == "list" then
			visitExpression(node.value, visitor)
		elseif node.kind == "record" then
			visitToken(node.key, visitor)
			visitToken(node.equals, visitor)
			visitExpression(node.value, visitor)
		elseif node.kind == "general" then
			visitToken(node.indexeropen, visitor)
			visitExpression(node.key, visitor)
			visitToken(node.indexerclose, visitor)
			visitToken(node.equals, visitor)
			visitExpression(node.value, visitor)
		else
			exhaustiveMatch(node.kind)
		end

		if node.separator then
			visitToken(node.separator, visitor)
		end
	end
end

local function visitTable(node: types.AstExprTable, visitor: Visitor)
	if visitor.visitTable(node) then
		visitToken(node.openbrace, visitor)
		for _, item in node.entries do
			visitTableItem(item, visitor)
		end
		visitToken(node.closebrace, visitor)
	end
end

local function visitIndexName(node: types.AstExprIndexName, visitor: Visitor)
	if visitor.visitIndexName(node) then
		visitExpression(node.expression, visitor)
		visitToken(node.accessor, visitor)
		visitToken(node.index, visitor)
	end
end

local function visitIndexExpr(node: types.AstExprIndexExpr, visitor: Visitor)
	if visitor.visitIndexExpr(node) then
		visitExpression(node.expression, visitor)
		visitToken(node.openbrackets, visitor)
		visitExpression(node.index, visitor)
		visitToken(node.closebrackets, visitor)
	end
end

local function visitGroup(node: types.AstExprGroup, visitor: Visitor)
	if visitor.visitGroup(node) then
		visitToken(node.openparens, visitor)
		visitExpression(node.expression, visitor)
		visitToken(node.closeparens, visitor)
	end
end

local function visitInterpolatedString(node: types.AstExprInterpString, visitor: Visitor)
	if visitor.visitInterpolatedString(node) then
		for i = 1, #node.strings do
			visitToken(node.strings[i], visitor)
			if i <= #node.expressions then
				visitExpression(node.expressions[i], visitor)
			end
		end
	end
end

local function visitTypeAssertion(node: types.AstExprTypeAssertion, visitor: Visitor)
	if visitor.visitTypeAssertion(node) then
		visitExpression(node.operand, visitor)
		visitToken(node.operator, visitor)
		visitType(node.annotation, visitor)
	end
end

local function visitIfExpression(node: types.AstExprIfElse, visitor: Visitor)
	if visitor.visitIfExpression(node) then
		visitToken(node.ifkeyword, visitor)
		visitExpression(node.condition, visitor)
		visitToken(node.thenkeyword, visitor)
		visitExpression(node.thenexpr, visitor)
		for _, elseifs in node.elseifs do
			visitToken(elseifs.elseifkeyword, visitor)
			visitExpression(elseifs.condition, visitor)
			visitToken(elseifs.thenkeyword, visitor)
			visitExpression(elseifs.thenexpr, visitor)
		end
		visitToken(node.elsekeyword, visitor)
		visitExpression(node.elseexpr, visitor)
	end
end

local function visitTypeOrPack(node: types.AstType | types.AstTypePack, visitor: Visitor)
	if node.kind == "typepack" then
		visitTypePack(node, visitor)
	else
		visitType(node, visitor)
	end
end

local function visitTypeReference(node: types.AstTypeReference, visitor: Visitor)
	if visitor.visitTypeReference(node) then
		if node.prefix then
			visitToken(node.prefix, visitor)
		end
		if node.prefixpoint then
			visitToken(node.prefixpoint, visitor)
		end
		visitToken(node.name, visitor)
		if node.openparameters then
			visitToken(node.openparameters, visitor)
		end
		if node.parameters then
			visitPunctuated(node.parameters, visitor, visitTypeOrPack)
		end
		if node.closeparameters then
			visitToken(node.closeparameters, visitor)
		end
	end
end

local function visitTypeBoolean(node: types.AstTypeSingletonBool, visitor: Visitor)
	if visitor.visitTypeBoolean(node) then
		visitToken(node, visitor)
	end
end

local function visitTypeString(node: types.AstTypeSingletonString, visitor: Visitor)
	if visitor.visitTypeString(node) then
		visitToken(node, visitor)
	end
end

local function visitTypeTypeof(node: types.AstTypeTypeof, visitor: Visitor)
	if visitor.visitTypeTypeof(node) then
		visitToken(node.typeof, visitor)
		visitToken(node.openparens, visitor)
		visitExpression(node.expression, visitor)
		visitToken(node.closeparens, visitor)
	end
end

local function visitTypeGroup(node: types.AstTypeGroup, visitor: Visitor)
	if visitor.visitTypeGroup(node) then
		visitToken(node.openparens, visitor)
		visitType(node.type, visitor)
		visitToken(node.closeparens, visitor)
	end
end

local function visitTypeUnion(node: types.AstTypeUnion, visitor: Visitor)
	if visitor.visitTypeUnion(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeIntersection(node: types.AstTypeIntersection, visitor: Visitor)
	if visitor.visitTypeIntersection(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeArray(node: types.AstTypeArray, visitor: Visitor)
	if visitor.visitTypeArray(node) then
		visitToken(node.openbrace, visitor)
		if node.access then
			visitToken(node.access, visitor)
		end
		visitType(node.type, visitor)
		visitToken(node.closebrace, visitor)
	end
end

local function visitTypeTable(node: types.AstTypeTable, visitor: Visitor)
	if visitor.visitTypeTable(node) then
		visitToken(node.openbrace, visitor)
		for _, entry in node.entries do
			if entry.access then
				visitToken(entry.access, visitor)
			end
			if entry.kind == "indexer" then
				visitToken(entry.indexeropen, visitor)
				visitType(entry.key, visitor)
				visitToken(entry.indexerclose, visitor)
			elseif entry.kind == "stringproperty" then
				visitToken(entry.indexeropen, visitor)
				visitTypeString(entry.key, visitor)
				visitToken(entry.indexerclose, visitor)
			else
				visitToken(entry.key, visitor)
			end
			visitToken(entry.colon, visitor)
			visitType(entry.value, visitor)
			if entry.separator then
				visitToken(entry.separator, visitor)
			end
		end
		visitToken(node.closebrace, visitor)
	end
end

local function visitTypeFunctionParameter(node: types.AstTypeFunctionParameter, visitor)
	if node.name then
		visitToken(node.name, visitor)
	end
	if node.colon then
		visitToken(node.colon, visitor)
	end
	visitType(node.type, visitor)
end

local function visitTypeFunction(node: types.AstTypeFunction, visitor: Visitor)
	if visitor.visitTypeFunction(node) then
		if node.opengenerics then
			visitToken(node.opengenerics, visitor)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric)
		end
		if node.genericpacks then
			visitPunctuated(node.genericpacks, visitor, visitGenericPack)
		end
		if node.closegenerics then
			visitToken(node.closegenerics, visitor)
		end
		visitToken(node.openparens, visitor)
		visitPunctuated(node.parameters, visitor, visitTypeFunctionParameter)
		if node.vararg then
			visitTypePack(node.vararg, visitor)
		end
		visitToken(node.closeparens, visitor)
		visitToken(node.returnarrow, visitor)
		visitTypePack(node.returntypes, visitor)
	end
end

local function visitTypePackExplicit(node: types.AstTypePackExplicit, visitor: Visitor)
	if visitor.visitTypePackExplicit(node) then
		if node.openparens then
			visitToken(node.openparens, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
		if node.tailtype then
			visitTypePack(node.tailtype, visitor)
		end
		if node.closeparens then
			visitToken(node.closeparens, visitor)
		end
	end
end

local function visitTypePackGeneric(node: types.AstTypePackGeneric, visitor: Visitor)
	if visitor.visitTypePackGeneric(node) then
		visitToken(node.name, visitor)
		visitToken(node.ellipsis, visitor)
	end
end

local function visitTypePackVariadic(node: types.AstTypePackVariadic, visitor: Visitor)
	if visitor.visitTypePackVariadic(node) then
		if node.ellipsis then
			visitToken(node.ellipsis, visitor)
		end
		visitType(node.type, visitor)
	end
end

function visitExpression(expression: types.AstExpr, visitor: Visitor)
	if visitor.visitExpression(expression) then
		if expression.tag == "nil" then
			visitNil(expression, visitor)
		elseif expression.tag == "boolean" then
			visitBoolean(expression, visitor)
		elseif expression.tag == "number" then
			visitNumber(expression, visitor)
		elseif expression.tag == "string" then
			visitString(expression, visitor)
		elseif expression.tag == "local" then
			visitLocalReference(expression, visitor)
		elseif expression.tag == "global" then
			visitGlobal(expression, visitor)
		elseif expression.tag == "vararg" then
			visitVarargs(expression, visitor)
		elseif expression.tag == "call" then
			visitCall(expression, visitor)
		elseif expression.tag == "unary" then
			visitUnary(expression, visitor)
		elseif expression.tag == "binary" then
			visitBinary(expression, visitor)
		elseif expression.tag == "function" then
			visitAnonymousFunction(expression, visitor)
		elseif expression.tag == "table" then
			visitTable(expression, visitor)
		elseif expression.tag == "indexname" then
			visitIndexName(expression, visitor)
		elseif expression.tag == "index" then
			visitIndexExpr(expression, visitor)
		elseif expression.tag == "group" then
			visitGroup(expression, visitor)
		elseif expression.tag == "interpolatedstring" then
			visitInterpolatedString(expression, visitor)
		elseif expression.tag == "cast" then
			visitTypeAssertion(expression, visitor)
		elseif expression.tag == "conditional" then
			visitIfExpression(expression, visitor)
		else
			exhaustiveMatch(expression.tag)
		end

		visitor.visitExpressionEnd(expression)
	end
end

function visitStatement(statement: types.AstStat, visitor: Visitor)
	if statement.tag == "block" then
		visitBlock(statement, visitor)
	elseif statement.tag == "conditional" then
		visitIf(statement, visitor)
	elseif statement.tag == "expression" then
		visitExpression(statement.expression, visitor)
	elseif statement.tag == "local" then
		visitLocalStatement(statement, visitor)
	elseif statement.tag == "return" then
		visitReturn(statement, visitor)
	elseif statement.tag == "while" then
		visitWhile(statement, visitor)
	elseif statement.tag == "break" then
		visitToken(statement, visitor)
	elseif statement.tag == "continue" then
		visitToken(statement, visitor)
	elseif statement.tag == "repeat" then
		visitRepeat(statement, visitor)
	elseif statement.tag == "for" then
		visitFor(statement, visitor)
	elseif statement.tag == "forin" then
		visitForIn(statement, visitor)
	elseif statement.tag == "assign" then
		visitAssign(statement, visitor)
	elseif statement.tag == "compoundassign" then
		visitCompoundAssign(statement, visitor)
	elseif statement.tag == "function" then
		visitFunction(statement, visitor)
	elseif statement.tag == "localfunction" then
		visitLocalFunction(statement, visitor)
	elseif statement.tag == "typealias" then
		visitTypeAlias(statement, visitor)
	elseif statement.tag == "typefunction" then
		visitStatTypeFunction(statement, visitor)
	else
		exhaustiveMatch(statement.tag)
	end
end

function visitType(type: types.AstType, visitor: Visitor)
	if type.tag == "reference" then
		visitTypeReference(type, visitor)
	elseif type.tag == "boolean" then
		visitTypeBoolean(type, visitor)
	elseif type.tag == "string" then
		visitTypeString(type, visitor)
	elseif type.tag == "typeof" then
		visitTypeTypeof(type, visitor)
	elseif type.tag == "group" then
		visitTypeGroup(type, visitor)
	elseif type.tag == "union" then
		visitTypeUnion(type, visitor)
	elseif type.tag == "intersection" then
		visitTypeIntersection(type, visitor)
	elseif type.tag == "optional" then
		visitToken(type, visitor)
	elseif type.tag == "array" then
		visitTypeArray(type, visitor)
	elseif type.tag == "table" then
		visitTypeTable(type, visitor)
	elseif type.tag == "function" then
		visitTypeFunction(type, visitor)
	else
		exhaustiveMatch(type.tag)
	end
end

function visitTypePack(type: types.AstTypePack, visitor: Visitor)
	if type.tag == "explicit" then
		visitTypePackExplicit(type, visitor)
	elseif type.tag == "generic" then
		visitTypePackGeneric(type, visitor)
	elseif type.tag == "variadic" then
		visitTypePackVariadic(type, visitor)
	else
		exhaustiveMatch(type.tag)
	end
end

local function create(visit: ((types.AstNode) -> boolean)?): Visitor
	if visit then
		return {
			visitBlock = visit,
			visitBlockEnd = visit,
			visitIf = visit,
			visitWhile = visit,
			visitRepeat = visit,
			visitReturn = visit,
			visitLocalDeclaration = visit,
			visitLocalDeclarationEnd = visit,
			visitFor = visit,
			visitForIn = visit,
			visitAssign = visit,
			visitCompoundAssign = visit,
			visitFunction = visit,
			visitLocalFunction = visit,
			visitTypeAlias = visit,
			visitStatTypeFunction = visit,

			visitExpression = visit,
			visitExpressionEnd = visit,
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
	else
		return table.clone(defaultVisitor)
	end
end

local function visit(node: types.AstNode, visitor: Visitor)
	if node.kind == "stat" then
		visitStatement(node, visitor)
	elseif node.kind == "expr" then
		visitExpression(node, visitor)
	elseif node.kind == "type" then
		visitType(node, visitor)
	elseif node.kind == "typepack" then
		visitTypePack(node, visitor)
	elseif node.kind == "local" then
		visitLocal(node, visitor)
	elseif node.kind == "attribute" then
		visitAttribute(node, visitor)
	else
		exhaustiveMatch(node.kind)
	end
end

visitorlib.create = create
visitorlib.visitblock = visitBlock
visitorlib.visitstatement = visitStatement
visitorlib.visitexpression = visitExpression
visitorlib.visittype = visitType
visitorlib.visittypepack = visitTypePack
visitorlib.visittoken = visitToken
visitorlib.visit = visit

return table.freeze(visitorlib)
