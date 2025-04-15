--!strict

local T = require("./ast_types")

export type Visitor = {
	visitBlock: (T.AstStatBlock) -> boolean,
	visitBlockEnd: (T.AstStatBlock) -> (),
	visitIf: (T.AstStatIf) -> boolean,
	visitWhile: (T.AstStatWhile) -> boolean,
	visitRepeat: (T.AstStatRepeat) -> boolean,
	visitReturn: (T.AstStatReturn) -> boolean,
	visitLocalDeclaration: (T.AstStatLocal) -> boolean,
	visitFor: (T.AstStatFor) -> boolean,
	visitForIn: (T.AstStatForIn) -> boolean,
	visitAssign: (T.AstStatAssign) -> boolean,
	visitCompoundAssign: (T.AstStatCompoundAssign) -> boolean,
	visitFunction: (T.AstStatFunction) -> boolean,
	visitLocalFunction: (T.AstStatLocalFunction) -> boolean,
	visitTypeAlias: (T.AstStatTypeAlias) -> boolean,

	visitExpression: (T.AstExpr) -> boolean,
	visitExpressionEnd: (T.AstExpr) -> (),
	visitLocalReference: (T.AstExprLocal) -> boolean,
	visitGlobal: (T.AstExprGlobal) -> boolean,
	visitCall: (T.AstExprCall) -> boolean,
	visitUnary: (T.AstExprUnary) -> boolean,
	visitBinary: (T.AstExprBinary) -> boolean,
	visitAnonymousFunction: (T.AstExprAnonymousFunction) -> boolean,
	visitTableItem: (T.AstExprTableItem) -> boolean,
	visitTable: (T.AstExprTable) -> boolean,
	visitIndexName: (T.AstExprIndexName) -> boolean,
	visitIndexExpr: (T.AstExprIndexExpr) -> boolean,
	visitGroup: (T.AstExprGroup) -> boolean,
	visitInterpolatedString: (T.AstExprInterpString) -> boolean,
	visitTypeAssertion: (T.AstExprTypeAssertion) -> boolean,
	visitIfExpression: (T.AstExprIfElse) -> boolean,

	visitTypeReference: (T.AstTypeReference) -> boolean,
	visitTypeBoolean: (T.AstTypeSingletonBool) -> boolean,
	visitTypeString: (T.AstTypeSingletonString) -> boolean,
	visitTypeTypeof: (T.AstTypeTypeof) -> boolean,
	visitTypeGroup: (T.AstTypeGroup) -> boolean,

	visitToken: (T.Token) -> boolean,
	visitNil: (T.AstExprConstantNil) -> boolean,
	visitString: (T.AstExprConstantString) -> boolean,
	visitBoolean: (T.AstExprConstantBool) -> boolean,
	visitNumber: (T.AstExprConstantNumber) -> boolean,
	visitLocal: (T.AstLocal) -> boolean,
	visitVarargs: (T.AstExprVarargs) -> boolean,
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
	visitFor = alwaysVisit :: any,
	visitForIn = alwaysVisit :: any,
	visitAssign = alwaysVisit :: any,
	visitCompoundAssign = alwaysVisit :: any,
	visitFunction = alwaysVisit :: any,
	visitLocalFunction = alwaysVisit :: any,
	visitTypeAlias = alwaysVisit :: any,

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

local function visitToken<T>(token: T.Token<T>, visitor: Visitor)
	visitor.visitToken(token)
end

local function visitPunctuated<T, Separator>(list: T.Punctuated<T, Separator>, visitor: Visitor, apply: (T, Visitor) -> ())
	for _, item in list do
		apply(item.node, visitor)
		if item.separator then
			visitToken(item.separator, visitor)
		end
	end
end

local function visitLocal(node: T.AstLocal, visitor: Visitor)
	if visitor.visitLocal(node) then
		visitToken(node.name, visitor)
	end
end

local function visitBlock(block: T.AstStatBlock, visitor: Visitor)
	if visitor.visitBlock(block) then
		for _, statement in block.statements do
			visitStatement(statement, visitor)
		end

		visitor.visitBlockEnd(block)
	end
end

local function visitIf(node: T.AstStatIf, visitor: Visitor)
	if visitor.visitIf(node) then
		visitToken(node["if"], visitor)
		visitExpression(node.condition, visitor)
		visitToken(node["then"], visitor)
		visitBlock(node.consequent, visitor)
		for _, elseifNode in node.elseifs do
			visitToken(elseifNode["elseif"], visitor)
			visitExpression(elseifNode.condition, visitor)
			visitToken(elseifNode["then"], visitor)
			visitBlock(elseifNode.consequent, visitor)
		end
		if node["else"] then
			visitToken(node["else"], visitor)
		end
		if node.antecedent then
			visitBlock(node.antecedent, visitor)
		end
		visitToken(node["end"], visitor)
	end
end

local function visitWhile(node: T.AstStatWhile, visitor: Visitor)
	if visitor.visitWhile(node) then
		visitToken(node["while"], visitor)
		visitExpression(node.condition, visitor)
		visitToken(node["do"], visitor)
		visitBlock(node.body, visitor)
		visitToken(node["end"], visitor)
	end
end

local function visitRepeat(node: T.AstStatRepeat, visitor: Visitor)
	if visitor.visitRepeat(node) then
		visitToken(node["repeat"], visitor)
		visitBlock(node.body, visitor)
		visitToken(node["until"], visitor)
		visitExpression(node.condition, visitor)
	end
end

local function visitReturn(node: T.AstStatReturn, visitor: Visitor)
	if visitor.visitReturn(node) then
		visitToken(node["return"], visitor)
		visitPunctuated(node.expressions, visitor, visitExpression)
	end
end

local function visitLocalStatement(node: T.AstStatLocal, visitor: Visitor)
	if visitor.visitLocalDeclaration(node) then
		visitToken(node["local"], visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		if node.equals then
			visitToken(node.equals, visitor)
		end
		visitPunctuated(node.values, visitor, visitExpression)
	end
end

local function visitFor(node: T.AstStatFor, visitor: Visitor)
	if visitor.visitFor(node) then
		visitToken(node["for"], visitor)
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
		visitToken(node["do"], visitor)
		visitBlock(node.body, visitor)
		visitToken(node["end"], visitor)
	end
end

local function visitForIn(node: T.AstStatForIn, visitor: Visitor)
	if visitor.visitForIn(node) then
		visitToken(node["for"], visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		visitToken(node["in"], visitor)
		visitPunctuated(node.values, visitor, visitExpression)
		visitToken(node["do"], visitor)
		visitBlock(node.body, visitor)
		visitToken(node["end"], visitor)
	end
end

local function visitAssign(node: T.AstStatAssign, visitor: Visitor)
	if visitor.visitAssign(node) then
		visitPunctuated(node.variables, visitor, visitExpression)
		visitToken(node.equals, visitor)
		visitPunctuated(node.values, visitor, visitExpression)
	end
end

local function visitCompoundAssign(node: T.AstStatCompoundAssign, visitor: Visitor)
	if visitor.visitCompoundAssign(node) then
		visitExpression(node.variable, visitor)
		visitToken(node.operand, visitor)
		visitExpression(node.value, visitor)
	end
end

local function visitTypeAlias(node: T.AstStatTypeAlias, visitor: Visitor)
	if visitor.visitTypeAlias(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.typeToken, visitor)
		visitToken(node.name, visitor)
		visitToken(node.equals, visitor)
		visitType(node.type, visitor)
	end
end

local function visitString(node: T.AstExprConstantString, visitor: Visitor)
	if visitor.visitString(node) then
		visitor.visitToken(node)
	end
end

local function visitNil(node: T.AstExprConstantNil, visitor: Visitor)
	if visitor.visitNil(node) then
		visitToken(node, visitor)
	end
end

local function visitBoolean(node: T.AstExprConstantBool, visitor: Visitor)
	if visitor.visitBoolean(node) then
		visitToken(node, visitor)
	end
end

local function visitNumber(node: T.AstExprConstantNumber, visitor: Visitor)
	if visitor.visitNumber(node) then
		visitToken(node, visitor)
	end
end

local function visitLocalReference(node: T.AstExprLocal, visitor: Visitor)
	if visitor.visitLocalReference(node) then
		visitor.visitToken(node.token)
	end
end

local function visitGlobal(node: T.AstExprGlobal, visitor: Visitor)
	if visitor.visitGlobal(node) then
		visitor.visitToken(node.name)
	end
end

local function visitVarargs(node: T.AstExprVarargs, visitor: Visitor)
	if visitor.visitVarargs(node) then
		visitToken(node, visitor)
	end
end

local function visitCall(node: T.AstExprCall, visitor: Visitor)
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

local function visitUnary(node: T.AstExprUnary, visitor: Visitor)
	if visitor.visitUnary(node) then
		visitToken(node.operator, visitor)
		visitExpression(node.operand, visitor)
	end
end

local function visitBinary(node: T.AstExprBinary, visitor: Visitor)
	if visitor.visitBinary(node) then
		visitExpression(node.lhsoperand, visitor)
		visitToken(node.operator, visitor)
		visitExpression(node.rhsoperand, visitor)
	end
end

local function visitFunctionBody(node: T.AstFunctionBody, visitor: Visitor)
	visitToken(node.openParens, visitor)
	visitPunctuated(node.parameters, visitor, visitLocal)
	visitToken(node.closeParens, visitor)
	visitBlock(node.body, visitor)
	visitToken(node["end"], visitor)
end

local function visitAnonymousFunction(node: T.AstExprAnonymousFunction, visitor: Visitor)
	if visitor.visitAnonymousFunction(node) then
		visitToken(node["function"], visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitFunction(node: T.AstStatFunction, visitor: Visitor)
	if visitor.visitFunction(node) then
		visitToken(node["function"], visitor)
		visitExpression(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitLocalFunction(node: T.AstStatLocalFunction, visitor: Visitor)
	if visitor.visitLocalFunction(node) then
		visitToken(node["local"], visitor)
		visitToken(node["function"], visitor)
		visitLocal(node.name, visitor)
		visitFunctionBody(node.body, visitor)
	end
end

local function visitTableItem(node: T.AstExprTableItem, visitor: Visitor)
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

local function visitTable(node: T.AstExprTable, visitor: Visitor)
	if visitor.visitTable(node) then
		visitToken(node.openBrace, visitor)
		for _, item in node.entries do
			visitTableItem(item, visitor)
		end
		visitToken(node.closeBrace, visitor)
	end
end

local function visitIndexName(node: T.AstExprIndexName, visitor: Visitor)
	if visitor.visitIndexName(node) then
		visitExpression(node.expr, visitor)
		visitToken(node.accessor, visitor)
		visitToken(node.index, visitor)
	end
end

local function visitIndexExpr(node: T.AstExprIndexExpr, visitor: Visitor)
	if visitor.visitIndexExpr(node) then
		visitExpression(node.expr, visitor)
		visitToken(node.openBrackets, visitor)
		visitExpression(node.index, visitor)
		visitToken(node.closeBrackets, visitor)
	end
end

local function visitGroup(node: T.AstExprGroup, visitor: Visitor)
	if visitor.visitGroup(node) then
		visitToken(node.openParens, visitor)
		visitExpression(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitInterpolatedString(node: T.AstExprInterpString, visitor: Visitor)
	if visitor.visitInterpolatedString(node) then
		for i = 1, #node.strings do
			visitToken(node.strings[i], visitor)
			if i < #node.expressions then
				visitExpression(node.expressions[i], visitor)
			end
		end
	end
end

local function visitTypeAssertion(node: T.AstExprTypeAssertion, visitor: Visitor)
	if visitor.visitTypeAssertion(node) then
		visitExpression(node.operand, visitor)
		visitToken(node.operator, visitor)
		visitType(node.annotation, visitor)
	end
end

local function visitIfExpression(node: T.AstExprIfElse, visitor: Visitor)
	if visitor.visitIfExpression(node) then
		visitToken(node["if"], visitor)
		visitExpression(node.condition, visitor)
		visitToken(node["then"], visitor)
		visitExpression(node.consequent, visitor)
		for _, elseifs in node["elseifs"] do
			visitToken(elseifs["elseif"], visitor)
			visitExpression(elseifs.condition, visitor)
			visitToken(elseifs["then"], visitor)
			visitExpression(elseifs.consequent, visitor)
		end
		visitToken(node["else"], visitor)
		visitExpression(node.antecedent, visitor)
	end
end

local function visitTypeReference(node: T.AstTypeReference, visitor: Visitor)
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
			visitPunctuated(node.parameters, visitor, visitType)
		end
		if node.closeParameters then
			visitToken(node.closeParameters, visitor)
		end
	end
end

local function visitTypeBoolean(node: T.AstTypeSingletonBool, visitor: Visitor)
	if visitor.visitTypeBoolean(node) then
		visitToken(node, visitor)
	end
end

local function visitTypeString(node: T.AstTypeSingletonString, visitor: Visitor)
	if visitor.visitTypeString(node) then
		visitToken(node, visitor)
	end
end

local function visitTypeTypeof(node: T.AstTypeTypeof, visitor: Visitor)
	if visitor.visitTypeTypeof(node) then
		visitToken(node.typeof, visitor)
		visitToken(node.openParens, visitor)
		visitExpression(node.expr, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitTypeGroup(node: T.AstTypeGroup, visitor: Visitor)
	if visitor.visitTypeGroup(node) then
		visitToken(node.openParens, visitor)
		visitType(node.type, visitor)
		visitToken(node.closeParens, visitor)
	end
end

function visitExpression(expression: T.AstExpr, visitor: Visitor)
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

function visitStatement(statement: T.AstStat, visitor: Visitor)
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
	else
		exhaustiveMatch(statement.tag)
	end
end

function visitType(type: T.AstType, visitor: Visitor)
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
	visitToken = visitToken,
}
