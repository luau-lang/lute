--!strict

local luau = require("@lute/luau")

export type Visitor = {
	visitBlock: (luau.AstStatBlock) -> boolean,
	visitBlockEnd: (luau.AstStatBlock) -> (),
	visitIf: (luau.AstStatIf) -> boolean,
	visitWhile: (luau.AstStatWhile) -> boolean,
	visitRepeat: (luau.AstStatRepeat) -> boolean,
	visitReturn: (luau.AstStatReturn) -> boolean,
	visitLocalDeclaration: (luau.AstStatLocal) -> boolean,
	visitLocalDeclarationEnd: (luau.AstStatLocal) -> (),
	visitFor: (luau.AstStatFor) -> boolean,
	visitForIn: (luau.AstStatForIn) -> boolean,
	visitAssign: (luau.AstStatAssign) -> boolean,
	visitCompoundAssign: (luau.AstStatCompoundAssign) -> boolean,
	visitFunction: (luau.AstStatFunction) -> boolean,
	visitLocalFunction: (luau.AstStatLocalFunction) -> boolean,
	visitTypeAlias: (luau.AstStatTypeAlias) -> boolean,
	visitStatTypeFunction: (luau.AstStatTypeFunction) -> boolean,

	visitExpression: (luau.AstExpr) -> boolean,
	visitExpressionEnd: (luau.AstExpr) -> (),
	visitLocalReference: (luau.AstExprLocal) -> boolean,
	visitGlobal: (luau.AstExprGlobal) -> boolean,
	visitCall: (luau.AstExprCall) -> boolean,
	visitUnary: (luau.AstExprUnary) -> boolean,
	visitBinary: (luau.AstExprBinary) -> boolean,
	visitAnonymousFunction: (luau.AstExprAnonymousFunction) -> boolean,
	visitTableItem: (luau.AstExprTableItem) -> boolean,
	visitTable: (luau.AstExprTable) -> boolean,
	visitIndexName: (luau.AstExprIndexName) -> boolean,
	visitIndexExpr: (luau.AstExprIndexExpr) -> boolean,
	visitGroup: (luau.AstExprGroup) -> boolean,
	visitInterpolatedString: (luau.AstExprInterpString) -> boolean,
	visitTypeAssertion: (luau.AstExprTypeAssertion) -> boolean,
	visitIfExpression: (luau.AstExprIfElse) -> boolean,

	visitTypeReference: (luau.AstTypeReference) -> boolean,
	visitTypeBoolean: (luau.AstTypeSingletonBool) -> boolean,
	visitTypeString: (luau.AstTypeSingletonString) -> boolean,
	visitTypeTypeof: (luau.AstTypeTypeof) -> boolean,
	visitTypeGroup: (luau.AstTypeGroup) -> boolean,
	visitTypeUnion: (luau.AstTypeUnion) -> boolean,
	visitTypeIntersection: (luau.AstTypeIntersection) -> boolean,
	visitTypeArray: (luau.AstTypeArray) -> boolean,
	visitTypeTable: (luau.AstTypeTable) -> boolean,
	visitTypeFunction: (luau.AstTypeFunction) -> boolean,

	visitTypePackExplicit: (luau.AstTypePackExplicit) -> boolean,
	visitTypePackGeneric: (luau.AstTypePackGeneric) -> boolean,
	visitTypePackVariadic: (luau.AstTypePackVariadic) -> boolean,

	visitToken: (luau.Token) -> boolean,
	visitNil: (luau.AstExprConstantNil) -> boolean,
	visitString: (luau.AstExprConstantString) -> boolean,
	visitBoolean: (luau.AstExprConstantBool) -> boolean,
	visitNumber: (luau.AstExprConstantNumber) -> boolean,
	visitLocal: (luau.AstLocal) -> boolean,
	visitVarargs: (luau.AstExprVarargs) -> boolean,
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

local function visitToken<T>(token: luau.Token<T>, visitor: Visitor)
	visitor.visitToken(token)
end

local function visitPunctuated<T, Separator>(list: luau.Punctuated<T, Separator>, visitor: Visitor, apply: (T, Visitor) -> ())
	for _, item in list do
		apply(item.node, visitor)
		if item.separator then
			visitToken(item.separator, visitor)
		end
	end
end

local function visitLocal(node: luau.AstLocal, visitor: Visitor)
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

local function visitBlock(block: luau.AstStatBlock, visitor: Visitor)
	if visitor.visitBlock(block) then
		for _, statement in block.statements do
			visitStatement(statement, visitor)
		end

		visitor.visitBlockEnd(block)
	end
end

local function visitIf(node: luau.AstStatIf, visitor: Visitor)
	if visitor.visitIf(node) then
		visitToken(node.ifKeyword, visitor)
		visitExpression(node.condition, visitor)
		visitToken(node.thenKeyword, visitor)
		visitBlock(node.consequent, visitor)
		for _, elseifNode in node.elseifs do
			visitToken(elseifNode.elseifKeyword, visitor)
			visitExpression(elseifNode.condition, visitor)
			visitToken(elseifNode.thenKeyword, visitor)
			visitBlock(elseifNode.consequent, visitor)
		end
		if node.elseKeyword then
			visitToken(node.elseKeyword, visitor)
		end
		if node.antecedent then
			visitBlock(node.antecedent, visitor)
		end
		visitToken(node.endKeyword, visitor)
	end
end

local function visitWhile(node: luau.AstStatWhile, visitor: Visitor)
	if visitor.visitWhile(node) then
		visitToken(node.whileKeyword, visitor)
		visitExpression(node.condition, visitor)
		visitToken(node.doKeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
	end
end

local function visitRepeat(node: luau.AstStatRepeat, visitor: Visitor)
	if visitor.visitRepeat(node) then
		visitToken(node.repeatKeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.untilKeyword, visitor)
		visitExpression(node.condition, visitor)
	end
end

local function visitReturn(node: luau.AstStatReturn, visitor: Visitor)
	if visitor.visitReturn(node) then
		visitToken(node.returnKeyword, visitor)
		visitPunctuated(node.expressions, visitor, visitExpression)
	end
end

local function visitLocalStatement(node: luau.AstStatLocal, visitor: Visitor)
	if visitor.visitLocalDeclaration(node) then
		visitToken(node.localKeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		if node.equals then
			visitToken(node.equals, visitor)
		end
		visitPunctuated(node.values, visitor, visitExpression)

		visitor.visitLocalDeclarationEnd(node)
	end
end

local function visitFor(node: luau.AstStatFor, visitor: Visitor)
	if visitor.visitFor(node) then
		visitToken(node.forKeyword, visitor)
		visitLocal(node.variable, visitor)
		visitToken(node.equals, visitor)
		visitExpression(node.from, visitor)
		visitToken(node.toComma, visitor)
		visitExpression(node.to, visitor)
		if node.stepComma then
			visitToken(node.stepComma, visitor)
		end
		if node.step then
			visitExpression(node.step, visitor)
		end
		visitToken(node.doKeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
	end
end

local function visitForIn(node: luau.AstStatForIn, visitor: Visitor)
	if visitor.visitForIn(node) then
		visitToken(node.forKeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		visitToken(node.inKeyword, visitor)
		visitPunctuated(node.values, visitor, visitExpression)
		visitToken(node.doKeyword, visitor)
		visitBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
	end
end

local function visitAssign(node: luau.AstStatAssign, visitor: Visitor)
	if visitor.visitAssign(node) then
		visitPunctuated(node.variables, visitor, visitExpression)
		visitToken(node.equals, visitor)
		visitPunctuated(node.values, visitor, visitExpression)
	end
end

local function visitCompoundAssign(node: luau.AstStatCompoundAssign, visitor: Visitor)
	if visitor.visitCompoundAssign(node) then
		visitExpression(node.variable, visitor)
		visitToken(node.operand, visitor)
		visitExpression(node.value, visitor)
	end
end

local function visitGeneric(node: luau.AstGenericType, visitor: Visitor)
	visitToken(node.name, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitType(node.default, visitor)
	end
end

local function visitGenericPack(node: luau.AstGenericTypePack, visitor: Visitor)
	visitToken(node.name, visitor)
	visitToken(node.ellipsis, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitTypePack(node.default, visitor)
	end
end

local function visitTypeAlias(node: luau.AstStatTypeAlias, visitor: Visitor)
	if visitor.visitTypeAlias(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.typeToken, visitor)
		visitToken(node.name, visitor)
		if node.openGenerics then
			visitToken(node.openGenerics, visitor)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric)
		end
		if node.genericPacks then
			visitPunctuated(node.genericPacks, visitor, visitGenericPack)
		end
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor)
		end
		visitToken(node.equals, visitor)
		visitType(node.type, visitor)
	end
end

local function visitString(node: luau.AstExprConstantString, visitor: Visitor)
	if visitor.visitString(node) then
		visitor.visitToken(node)
	end
end

local function visitNil(node: luau.AstExprConstantNil, visitor: Visitor)
	if visitor.visitNil(node) then
		visitToken(node, visitor)
	end
end

local function visitBoolean(node: luau.AstExprConstantBool, visitor: Visitor)
	if visitor.visitBoolean(node) then
		visitToken(node, visitor)
	end
end

local function visitNumber(node: luau.AstExprConstantNumber, visitor: Visitor)
	if visitor.visitNumber(node) then
		visitToken(node, visitor)
	end
end

local function visitLocalReference(node: luau.AstExprLocal, visitor: Visitor)
	if visitor.visitLocalReference(node) then
		visitor.visitToken(node.token)
	end
end

local function visitGlobal(node: luau.AstExprGlobal, visitor: Visitor)
	if visitor.visitGlobal(node) then
		visitor.visitToken(node.name)
	end
end

local function visitVarargs(node: luau.AstExprVarargs, visitor: Visitor)
	if visitor.visitVarargs(node) then
		visitToken(node, visitor)
	end
end

local function visitCall(node: luau.AstExprCall, visitor: Visitor)
	if visitor.visitCall(node) then
		visitExpression(node.func, visitor)
		if node.openParens then
			visitToken(node.openParens, visitor)
		end
		visitPunctuated(node.arguments, visitor, visitExpression)
		if node.closeParens then
			visitToken(node.closeParens, visitor)
		end
	end
end

local function visitUnary(node: luau.AstExprUnary, visitor: Visitor)
	if visitor.visitUnary(node) then
		visitToken(node.operator, visitor)
		visitExpression(node.operand, visitor)
	end
end

local function visitBinary(node: luau.AstExprBinary, visitor: Visitor)
	if visitor.visitBinary(node) then
		visitExpression(node.lhsoperand, visitor)
		visitToken(node.operator, visitor)
		visitExpression(node.rhsoperand, visitor)
	end
end

local function visitFunctionBody(node: luau.AstFunctionBody, visitor: Visitor)
	if node.openGenerics then
		visitToken(node.openGenerics, visitor)
	end
	if node.generics then
		visitPunctuated(node.generics, visitor, visitGeneric)
	end
	if node.genericPacks then
		visitPunctuated(node.genericPacks, visitor, visitGenericPack)
	end
	if node.closeGenerics then
		visitToken(node.closeGenerics, visitor)
	end
	visitToken(node.openParens, visitor)
	visitPunctuated(node.parameters, visitor, visitLocal)
	if node.vararg then
		visitToken(node.vararg, visitor)
	end
	if node.varargColon then
		visitToken(node.varargColon, visitor)
	end
	if node.varargAnnotation then
		visitTypePack(node.varargAnnotation, visitor)
	end
	visitToken(node.closeParens, visitor)
	if node.returnSpecifier then
		visitToken(node.returnSpecifier, visitor)
	end
	if node.returnAnnotation then
		visitTypePack(node.returnAnnotation, visitor)
	end
	visitBlock(node.body, visitor)
	visitToken(node.endKeyword, visitor)
end

local function visitAttribute(node: luau.AstAttribute, visitor)
	visitToken(node, visitor)
end

local function visitAnonymousFunction(node: luau.AstExprAnonymousFunction, visitor: Visitor)
	if visitor.visitAnonymousFunction(node) then
		for _, attribute in node.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.functionKeyword, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitFunction(node: luau.AstStatFunction, visitor: Visitor)
	if visitor.visitFunction(node) then
		for _, attribute in node.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.functionKeyword, visitor)
		visitExpression(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitLocalFunction(node: luau.AstStatLocalFunction, visitor: Visitor)
	if visitor.visitLocalFunction(node) then
		for _, attribute in node.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.localKeyword, visitor)
		visitToken(node.functionKeyword, visitor)
		visitLocal(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitStatTypeFunction(node: luau.AstStatTypeFunction, visitor: Visitor)
	if visitor.visitStatTypeFunction(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.type, visitor)
		visitToken(node.functionKeyword, visitor)
		visitToken(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitTableItem(node: luau.AstExprTableItem, visitor: Visitor)
	if visitor.visitTableItem(node) then
		if node.kind == "list" then
			visitExpression(node.value, visitor)
		elseif node.kind == "record" then
			visitToken(node.key, visitor)
			visitToken(node.equals, visitor)
			visitExpression(node.value, visitor)
		elseif node.kind == "general" then
			visitToken(node.indexerOpen, visitor)
			visitExpression(node.key, visitor)
			visitToken(node.indexerClose, visitor)
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

local function visitTable(node: luau.AstExprTable, visitor: Visitor)
	if visitor.visitTable(node) then
		visitToken(node.openBrace, visitor)
		for _, item in node.entries do
			visitTableItem(item, visitor)
		end
		visitToken(node.closeBrace, visitor)
	end
end

local function visitIndexName(node: luau.AstExprIndexName, visitor: Visitor)
	if visitor.visitIndexName(node) then
		visitExpression(node.expression, visitor)
		visitToken(node.accessor, visitor)
		visitToken(node.index, visitor)
	end
end

local function visitIndexExpr(node: luau.AstExprIndexExpr, visitor: Visitor)
	if visitor.visitIndexExpr(node) then
		visitExpression(node.expression, visitor)
		visitToken(node.openBrackets, visitor)
		visitExpression(node.index, visitor)
		visitToken(node.closeBrackets, visitor)
	end
end

local function visitGroup(node: luau.AstExprGroup, visitor: Visitor)
	if visitor.visitGroup(node) then
		visitToken(node.openParens, visitor)
		visitExpression(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitInterpolatedString(node: luau.AstExprInterpString, visitor: Visitor)
	if visitor.visitInterpolatedString(node) then
		for i = 1, #node.strings do
			visitToken(node.strings[i], visitor)
			if i <= #node.expressions then
				visitExpression(node.expressions[i], visitor)
			end
		end
	end
end

local function visitTypeAssertion(node: luau.AstExprTypeAssertion, visitor: Visitor)
	if visitor.visitTypeAssertion(node) then
		visitExpression(node.operand, visitor)
		visitToken(node.operator, visitor)
		visitType(node.annotation, visitor)
	end
end

local function visitIfExpression(node: luau.AstExprIfElse, visitor: Visitor)
	if visitor.visitIfExpression(node) then
		visitToken(node.ifKeyword, visitor)
		visitExpression(node.condition, visitor)
		visitToken(node.thenKeyword, visitor)
		visitExpression(node.consequent, visitor)
		for _, elseifs in node.elseifs do
			visitToken(elseifs.elseifKeyword, visitor)
			visitExpression(elseifs.condition, visitor)
			visitToken(elseifs.thenKeyword, visitor)
			visitExpression(elseifs.consequent, visitor)
		end
		visitToken(node.elseKeyword, visitor)
		visitExpression(node.antecedent, visitor)
	end
end

local function visitTypeOrPack(node: luau.AstType | luau.AstTypePack, visitor: Visitor)
	if node.tag == "explicit" or node.tag == "generic" or node.tag == "variadic" then
		visitTypePack(node, visitor)
	else
		visitType(node, visitor)
	end
end

local function visitTypeReference(node: luau.AstTypeReference, visitor: Visitor)
	if visitor.visitTypeReference(node) then
		if node.prefix then
			visitToken(node.prefix, visitor)
		end
		if node.prefixPoint then
			visitToken(node.prefixPoint, visitor)
		end
		visitToken(node.name, visitor)
		if node.openParameters then
			visitToken(node.openParameters, visitor)
		end
		if node.parameters then
			visitPunctuated(node.parameters, visitor, visitTypeOrPack)
		end
		if node.closeParameters then
			visitToken(node.closeParameters, visitor)
		end
	end
end

local function visitTypeBoolean(node: luau.AstTypeSingletonBool, visitor: Visitor)
	if visitor.visitTypeBoolean(node) then
		visitToken(node, visitor)
	end
end

local function visitTypeString(node: luau.AstTypeSingletonString, visitor: Visitor)
	if visitor.visitTypeString(node) then
		visitToken(node, visitor)
	end
end

local function visitTypeTypeof(node: luau.AstTypeTypeof, visitor: Visitor)
	if visitor.visitTypeTypeof(node) then
		visitToken(node.typeof, visitor)
		visitToken(node.openParens, visitor)
		visitExpression(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitTypeGroup(node: luau.AstTypeGroup, visitor: Visitor)
	if visitor.visitTypeGroup(node) then
		visitToken(node.openParens, visitor)
		visitType(node.type, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitTypeUnion(node: luau.AstTypeUnion, visitor: Visitor)
	if visitor.visitTypeUnion(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeIntersection(node: luau.AstTypeIntersection, visitor: Visitor)
	if visitor.visitTypeIntersection(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeArray(node: luau.AstTypeArray, visitor: Visitor)
	if visitor.visitTypeArray(node) then
		visitToken(node.openBrace, visitor)
		if node.access then
			visitToken(node.access, visitor)
		end
		visitType(node.type, visitor)
		visitToken(node.closeBrace, visitor)
	end
end

local function visitTypeTable(node: luau.AstTypeTable, visitor: Visitor)
	if visitor.visitTypeTable(node) then
		visitToken(node.openBrace, visitor)
		for _, entry in node.entries do
			if entry.access then
				visitToken(entry.access, visitor)
			end
			if entry.kind == "indexer" then
				visitToken(entry.indexerOpen, visitor)
				visitType(entry.key, visitor)
				visitToken(entry.indexerClose, visitor)
			elseif entry.kind == "stringproperty" then
				visitToken(entry.indexerOpen, visitor)
				visitTypeString(entry.key, visitor)
				visitToken(entry.indexerClose, visitor)
			else
				visitToken(entry.key, visitor)
			end
			visitToken(entry.colon, visitor)
			visitType(entry.value, visitor)
			if entry.separator then
				visitToken(entry.separator, visitor)
			end
		end
		visitToken(node.closeBrace, visitor)
	end
end

local function visitTypeFunctionParameter(node: luau.AstTypeFunctionParameter, visitor)
	if node.name then
		visitToken(node.name, visitor)
	end
	if node.colon then
		visitToken(node.colon, visitor)
	end
	visitType(node.type, visitor)
end

local function visitTypeFunction(node: luau.AstTypeFunction, visitor: Visitor)
	if visitor.visitTypeFunction(node) then
		if node.openGenerics then
			visitToken(node.openGenerics, visitor)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric)
		end
		if node.genericPacks then
			visitPunctuated(node.genericPacks, visitor, visitGenericPack)
		end
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor)
		end
		visitToken(node.openParens, visitor)
		visitPunctuated(node.parameters, visitor, visitTypeFunctionParameter)
		if node.vararg then
			visitTypePack(node.vararg, visitor)
		end
		visitToken(node.closeParens, visitor)
		visitToken(node.returnArrow, visitor)
		visitTypePack(node.returnTypes, visitor)
	end
end

local function visitTypePackExplicit(node: luau.AstTypePackExplicit, visitor: Visitor)
	if visitor.visitTypePackExplicit(node) then
		if node.openParens then
			visitToken(node.openParens, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
		if node.tailType then
			visitTypePack(node.tailType, visitor)
		end
		if node.closeParens then
			visitToken(node.closeParens, visitor)
		end
	end
end

local function visitTypePackGeneric(node: luau.AstTypePackGeneric, visitor: Visitor)
	if visitor.visitTypePackGeneric(node) then
		visitToken(node.name, visitor)
		visitToken(node.ellipsis, visitor)
	end
end

local function visitTypePackVariadic(node: luau.AstTypePackVariadic, visitor: Visitor)
	if visitor.visitTypePackVariadic(node) then
		if node.ellipsis then
			visitToken(node.ellipsis, visitor)
		end
		visitType(node.type, visitor)
	end
end

function visitExpression(expression: luau.AstExpr, visitor: Visitor)
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

function visitStatement(statement: luau.AstStat, visitor: Visitor)
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

function visitType(type: luau.AstType, visitor: Visitor)
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

function visitTypePack(type: luau.AstTypePack, visitor: Visitor)
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

local function createVisitor()
	return table.clone(defaultVisitor)
end

return {
	createVisitor = createVisitor,
	visitBlock = visitBlock,
	visitStatement = visitStatement,
	visitExpression = visitExpression,
	visitType = visitType,
	visitTypePack = visitTypePack,
	visitToken = visitToken,
}
