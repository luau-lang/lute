--!strict
--!native
-- @std/syntax/visitor
-- Visitor pattern implementation for traversing Luau CST nodes

local types = require("./types")

local visitorlib = {}

--- A table of callbacks invoked during CST traversal. Each `visit` callback receives the corresponding node and
--- returns `true` to continue visiting its children, or `false` to skip them. "End" callbacks fire after all children
--- of that sort have been visited. Override only the callbacks you care about; unset callbacks default to visiting all children.
export type Visitor = {
	visitStatBlock: (types.CstStatBlock) -> boolean,
	visitStatBlockEnd: (types.CstStatBlock) -> (),
	visitStatDo: (types.CstStatDo) -> boolean,
	visitStatIf: (types.CstStatIf) -> boolean,
	visitStatWhile: (types.CstStatWhile) -> boolean,
	visitStatRepeat: (types.CstStatRepeat) -> boolean,
	visitStatBreak: (types.CstStatBreak) -> boolean,
	visitStatContinue: (types.CstStatContinue) -> boolean,
	visitStatReturn: (types.CstStatReturn) -> boolean,
	visitStatLocalDeclaration: (types.CstStatLocal) -> boolean,
	visitStatLocalDeclarationEnd: (types.CstStatLocal) -> (),
	visitStatConstDeclaration: (types.CstStatConst) -> boolean,
	visitStatConstDeclarationEnd: (types.CstStatConst) -> (),
	visitStatFor: (types.CstStatFor) -> boolean,
	visitStatForEnd: (types.CstStatFor) -> (),
	visitStatForIn: (types.CstStatForIn) -> boolean,
	visitStatForInEnd: (types.CstStatForIn) -> (),
	visitStatAssign: (types.CstStatAssign) -> boolean,
	visitStatCompoundAssign: (types.CstStatCompoundAssign) -> boolean,
	visitStatFunction: (types.CstStatFunction) -> boolean,
	visitStatLocalFunction: (types.CstStatLocalFunction) -> boolean,
	visitStatTypeAlias: (types.CstStatTypeAlias) -> boolean,
	visitStatTypeFunction: (types.CstStatTypeFunction) -> boolean,
	visitStatExpr: (types.CstStatExpr) -> boolean,

	visitExpr: (types.CstExpr) -> boolean,
	visitExprEnd: (types.CstExpr) -> (),
	visitExprConstantNil: (types.CstExprConstantNil) -> boolean,
	visitExprConstantString: (types.CstExprConstantString) -> boolean,
	visitExprConstantBool: (types.CstExprConstantBool) -> boolean,
	visitExprConstantNumber: (types.CstExprConstantNumber) -> boolean,
	visitExprConstantInteger: (types.CstExprConstantInteger) -> boolean,
	visitExprLocal: (types.CstExprLocal) -> boolean,
	visitExprGlobal: (types.CstExprGlobal) -> boolean,
	visitExprCall: (types.CstExprCall) -> boolean,
	visitExprUnary: (types.CstExprUnary) -> boolean,
	visitExprBinary: (types.CstExprBinary) -> boolean,
	visitExprFunction: (types.CstExprFunction) -> boolean,
	visitExprFunctionEnd: (types.CstExprFunction) -> (),
	visitExprInstantiate: (types.CstExprInstantiate) -> boolean,
	visitTableExprItem: (types.CstTableExprItem) -> boolean,
	visitExprTable: (types.CstExprTable) -> boolean,
	visitExprIndexName: (types.CstExprIndexName) -> boolean,
	visitExprIndexExpr: (types.CstExprIndexExpr) -> boolean,
	visitExprGroup: (types.CstExprGroup) -> boolean,
	visitExprInterpString: (types.CstExprInterpString) -> boolean,
	visitExprTypeAssertion: (types.CstExprTypeAssertion) -> boolean,
	visitExprIfElse: (types.CstExprIfElse) -> boolean,
	visitExprVarargs: (types.CstExprVarargs) -> boolean,

	visitTypeReference: (types.CstTypeReference) -> boolean,
	visitTypeSingletonBool: (types.CstTypeSingletonBool) -> boolean,
	visitTypeSingletonString: (types.CstTypeSingletonString) -> boolean,
	visitTypeTypeof: (types.CstTypeTypeof) -> boolean,
	visitTypeGroup: (types.CstTypeGroup) -> boolean,
	visitTypeOptional: (types.CstTypeOptional) -> boolean,
	visitTypeUnion: (types.CstTypeUnion) -> boolean,
	visitTypeIntersection: (types.CstTypeIntersection) -> boolean,
	visitTypeArray: (types.CstTypeArray) -> boolean,
	visitTypeTable: (types.CstTypeTable) -> boolean,
	visitTypeFunction: (types.CstTypeFunction) -> boolean,

	visitTypePackExplicit: (types.CstTypePackExplicit) -> boolean,
	visitTypePackGeneric: (types.CstTypePackGeneric) -> boolean,
	visitTypePackVariadic: (types.CstTypePackVariadic) -> boolean,

	visitToken: (types.CstToken) -> boolean,

	visitLocal: (types.CstLocal) -> boolean,

	visitAttribute: (types.CstAttribute) -> boolean,
	visitSimpleAttribute: (types.CstAttributeSimple) -> boolean,
	visitParametrizedAttribute: (types.CstAttributeParametrized) -> boolean,
	visitAttributeList: (types.CstAttributeList) -> boolean,
}

local function alwaysVisit(...: types.CstNode)
	return true
end

local defaultVisitor: Visitor = {
	visitStatBlock = alwaysVisit,
	visitStatBlockEnd = alwaysVisit :: (types.CstNode) -> (),
	visitStatDo = alwaysVisit,
	visitStatIf = alwaysVisit,
	visitStatWhile = alwaysVisit,
	visitStatRepeat = alwaysVisit,
	visitStatBreak = alwaysVisit,
	visitStatContinue = alwaysVisit,
	visitStatReturn = alwaysVisit,
	visitStatLocalDeclaration = alwaysVisit,
	visitStatLocalDeclarationEnd = alwaysVisit :: (types.CstNode) -> (),
	visitStatConstDeclaration = alwaysVisit,
	visitStatConstDeclarationEnd = alwaysVisit :: (types.CstNode) -> (),
	visitStatFor = alwaysVisit,
	visitStatForEnd = alwaysVisit :: (types.CstNode) -> (),
	visitStatForIn = alwaysVisit,
	visitStatForInEnd = alwaysVisit :: (types.CstNode) -> (),
	visitStatAssign = alwaysVisit,
	visitStatCompoundAssign = alwaysVisit,
	visitStatFunction = alwaysVisit,
	visitStatLocalFunction = alwaysVisit,
	visitStatTypeAlias = alwaysVisit,
	visitStatTypeFunction = alwaysVisit,
	visitStatExpr = alwaysVisit,

	visitExpr = alwaysVisit,
	visitExprConstantNil = alwaysVisit,
	visitExprConstantString = alwaysVisit,
	visitExprConstantBool = alwaysVisit,
	visitExprConstantNumber = alwaysVisit,
	visitExprConstantInteger = alwaysVisit,
	visitExprEnd = alwaysVisit :: (types.CstNode) -> (),
	visitExprLocal = alwaysVisit,
	visitExprGlobal = alwaysVisit,
	visitExprCall = alwaysVisit,
	visitExprUnary = alwaysVisit,
	visitExprBinary = alwaysVisit,
	visitExprFunction = alwaysVisit,
	visitExprFunctionEnd = alwaysVisit :: (types.CstNode) -> (),
	visitExprInstantiate = alwaysVisit,
	visitTableExprItem = alwaysVisit :: (types.CstTableExprItem) -> boolean,
	visitExprTable = alwaysVisit,
	visitExprIndexName = alwaysVisit,
	visitExprIndexExpr = alwaysVisit,
	visitExprGroup = alwaysVisit,
	visitExprInterpString = alwaysVisit,
	visitExprTypeAssertion = alwaysVisit,
	visitExprIfElse = alwaysVisit,
	visitExprVarargs = alwaysVisit,

	visitTypeReference = alwaysVisit,
	visitTypeSingletonBool = alwaysVisit,
	visitTypeSingletonString = alwaysVisit,
	visitTypeTypeof = alwaysVisit,
	visitTypeGroup = alwaysVisit,
	visitTypeOptional = alwaysVisit,
	visitTypeUnion = alwaysVisit,
	visitTypeIntersection = alwaysVisit,
	visitTypeArray = alwaysVisit,
	visitTypeTable = alwaysVisit :: (types.CstTypeTable) -> boolean, -- LUAUFIX: Code too complex emitted in absence of cast
	visitTypeFunction = alwaysVisit,

	visitTypePackExplicit = alwaysVisit,
	visitTypePackGeneric = alwaysVisit,
	visitTypePackVariadic = alwaysVisit,

	visitToken = alwaysVisit,

	visitLocal = alwaysVisit,

	visitAttribute = alwaysVisit,
	visitSimpleAttribute = alwaysVisit,
	visitParametrizedAttribute = alwaysVisit,
	visitAttributeList = alwaysVisit,
}

local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function visitToken<T>(token: types.CstToken<T>, visitor: Visitor)
	visitor.visitToken(token)
end

local function visitPunctuated<T, Separator>(list: types.CstPunctuated<T, Separator>, visitor: Visitor, apply: (T, Visitor) -> ())
	for i, item in list do
		apply(item, visitor)
		local sep = list.separators[i]
		if sep then
			visitToken(sep, visitor)
		end
	end
end

local function visitLocal(node: types.CstLocal, visitor: Visitor)
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

local function visitTypeOrTypePack(node: types.CstType | types.CstTypePack, visitor: Visitor)
	if node.kind == "type" then
		visitType(node, visitor)
	else
		visitTypePack(node, visitor)
	end
end

local function visitStatBlock(block: types.CstStatBlock, visitor: Visitor)
	if visitor.visitStatBlock(block) then
		for _, statement in block.statements do
			visitStatement(statement, visitor)
		end

		visitor.visitStatBlockEnd(block)
	end
end

local function visitStatDo(node: types.CstStatDo, visitor: Visitor)
	if visitor.visitStatDo(node) then
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
	end
end

local function visitStatIf(node: types.CstStatIf, visitor: Visitor)
	if visitor.visitStatIf(node) then
		visitToken(node.ifKeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.thenKeyword, visitor)
		visitStatBlock(node.thenBlock, visitor)
		for _, elseifNode in node.elseifs do
			visitToken(elseifNode.elseIfKeyword, visitor)
			visitExpr(elseifNode.condition, visitor)
			visitToken(elseifNode.thenKeyword, visitor)
			visitStatBlock(elseifNode.thenBlock, visitor)
		end
		if node.elseKeyword then
			visitToken(node.elseKeyword, visitor)
		end
		if node.elseBlock then
			visitStatBlock(node.elseBlock, visitor)
		end
		visitToken(node.endKeyword, visitor)
	end
end

local function visitStatWhile(node: types.CstStatWhile, visitor: Visitor)
	if visitor.visitStatWhile(node) then
		visitToken(node.whileKeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
	end
end

local function visitStatRepeat(node: types.CstStatRepeat, visitor: Visitor)
	if visitor.visitStatRepeat(node) then
		visitToken(node.repeatKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.untilKeyword, visitor)
		visitExpr(node.condition, visitor)
	end
end

local function visitStatBreak(node: types.CstStatBreak, visitor: Visitor)
	if visitor.visitStatBreak(node) then
		visitToken(node.token, visitor)
	end
end

local function visitStatContinue(node: types.CstStatContinue, visitor: Visitor)
	if visitor.visitStatContinue(node) then
		visitToken(node.token, visitor)
	end
end

local function visitStatReturn(node: types.CstStatReturn, visitor: Visitor)
	if visitor.visitStatReturn(node) then
		visitToken(node.returnKeyword, visitor)
		visitPunctuated(node.expressions, visitor, visitExpr)
	end
end

local function visitLocalStatement(node: types.CstStatLocal, visitor: Visitor)
	if visitor.visitStatLocalDeclaration(node) then
		visitToken(node.localKeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		if node.equals then
			visitToken(node.equals, visitor)
		end
		visitPunctuated(node.values, visitor, visitExpr)

		visitor.visitStatLocalDeclarationEnd(node)
	end
end

local function visitConstStatement(node: types.CstStatConst, visitor: Visitor)
	if visitor.visitStatConstDeclaration(node) then
		visitToken(node.constKeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		if node.equals then
			visitToken(node.equals, visitor)
		end
		visitPunctuated(node.values, visitor, visitExpr)

		visitor.visitStatConstDeclarationEnd(node)
	end
end

local function visitStatFor(node: types.CstStatFor, visitor: Visitor)
	if visitor.visitStatFor(node) then
		visitToken(node.forKeyword, visitor)
		visitLocal(node.variable, visitor)
		visitToken(node.equals, visitor)
		visitExpr(node.from, visitor)
		visitToken(node.toComma, visitor)
		visitExpr(node.to, visitor)
		if node.stepComma then
			visitToken(node.stepComma, visitor)
		end
		if node.step then
			visitExpr(node.step, visitor)
		end
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
		visitor.visitStatForEnd(node)
	end
end

local function visitStatForIn(node: types.CstStatForIn, visitor: Visitor)
	if visitor.visitStatForIn(node) then
		visitToken(node.forKeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		visitToken(node.inKeyword, visitor)
		visitPunctuated(node.values, visitor, visitExpr)
		visitToken(node.doKeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
		visitor.visitStatForInEnd(node)
	end
end

local function visitStatAssign(node: types.CstStatAssign, visitor: Visitor)
	if visitor.visitStatAssign(node) then
		visitPunctuated(node.variables, visitor, visitExpr)
		visitToken(node.equals, visitor)
		visitPunctuated(node.values, visitor, visitExpr)
	end
end

local function visitStatCompoundAssign(node: types.CstStatCompoundAssign, visitor: Visitor)
	if visitor.visitStatCompoundAssign(node) then
		visitExpr(node.variable, visitor)
		visitToken(node.operator, visitor)
		visitExpr(node.value, visitor)
	end
end

local function visitGeneric(node: types.CstGenericType, visitor: Visitor)
	visitToken(node.name, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitType(node.default, visitor)
	end
end

local function visitGenericPack(node: types.CstGenericTypePack, visitor: Visitor)
	visitToken(node.name, visitor)
	visitToken(node.ellipsis, visitor)
	if node.equals then
		visitToken(node.equals, visitor)
	end
	if node.default then
		visitTypePack(node.default, visitor)
	end
end

local function visitStatTypeAlias(node: types.CstStatTypeAlias, visitor: Visitor)
	if visitor.visitStatTypeAlias(node) then
		if node.isExported then
			assert(node.export)
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

local function visitStatExpr(node: types.CstStatExpr, visitor: Visitor)
	if visitor.visitStatExpr(node) then
		visitExpr(node.expression, visitor)
	end
end

local function visitExprConstantString(node: types.CstExprConstantString, visitor: Visitor)
	if visitor.visitExprConstantString(node) then
		visitor.visitToken(node.value)
	end
end

local function visitExprConstantNil(node: types.CstExprConstantNil, visitor: Visitor)
	if visitor.visitExprConstantNil(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprConstantBool(node: types.CstExprConstantBool, visitor: Visitor)
	if visitor.visitExprConstantBool(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprConstantNumber(node: types.CstExprConstantNumber, visitor: Visitor)
	if visitor.visitExprConstantNumber(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprConstantInteger(node: types.CstExprConstantInteger, visitor: Visitor)
	if visitor.visitExprConstantInteger(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprLocal(node: types.CstExprLocal, visitor: Visitor)
	if visitor.visitExprLocal(node) then
		visitor.visitToken(node.token)
	end
end

local function visitExprGlobal(node: types.CstExprGlobal, visitor: Visitor)
	if visitor.visitExprGlobal(node) then
		visitor.visitToken(node.name)
	end
end

local function visitExprVarargs(node: types.CstExprVarargs, visitor: Visitor)
	if visitor.visitExprVarargs(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprCall(node: types.CstExprCall, visitor: Visitor)
	if visitor.visitExprCall(node) then
		visitExpr(node.func, visitor)
		if node.openParens then
			visitToken(node.openParens, visitor)
		end
		visitPunctuated(node.arguments, visitor, visitExpr)
		if node.closeParens then
			visitToken(node.closeParens, visitor)
		end
	end
end

local function visitExprUnary(node: types.CstExprUnary, visitor: Visitor)
	if visitor.visitExprUnary(node) then
		visitToken(node.operator, visitor)
		visitExpr(node.operand, visitor)
	end
end

local function visitExprBinary(node: types.CstExprBinary, visitor: Visitor)
	if visitor.visitExprBinary(node) then
		visitExpr(node.lhsOperand, visitor)
		visitToken(node.operator, visitor)
		visitExpr(node.rhsOperand, visitor)
	end
end

local function visitSimpleAttribute(node: types.CstAttributeSimple, visitor: Visitor)
	if visitor.visitSimpleAttribute(node) then
		visitToken(node.name, visitor)
	end
end

local function visitParametrizedAttribute(node: types.CstAttributeParametrized, visitor: Visitor)
	if visitor.visitParametrizedAttribute(node) then
		visitToken(node.name, visitor)
		visitToken(node.openParens, visitor)
		visitPunctuated(node.arguments, visitor, visitExpr)
		visitToken(node.closeParens, visitor)
	end
end

local visitAttribute: (node: types.CstAttribute, visitor: Visitor) -> () = nil :: any

local function visitAttributeList(node: types.CstAttributeList, visitor: Visitor)
	if visitor.visitAttributeList(node) then
		visitToken(node.atBracket, visitor)
		visitPunctuated(node.attributes, visitor, visitAttribute)
		visitToken(node.closeBracket, visitor)
	end
end

visitAttribute = function(node: types.CstAttribute, visitor: Visitor)
	if visitor.visitAttribute(node) then
		if node.tag == "simple" then
			visitSimpleAttribute(node, visitor)
		elseif node.tag == "parametrized" then
			visitParametrizedAttribute(node, visitor)
		elseif node.tag == "list" then
			visitAttributeList(node, visitor)
		else
			exhaustiveMatch(node.tag)
		end
	end
end

local function visitExprFunction(
	node: types.CstExprFunction,
	visitor: Visitor,
	shouldVisitAttributes: boolean?,
	shouldVisitFunctionKeyword: boolean?
)
	if visitor.visitExprFunction(node) then
		if shouldVisitAttributes ~= false then
			for _, attribute in node.attributes do
				visitAttribute(attribute, visitor)
			end
		end
		if shouldVisitFunctionKeyword ~= false then
			visitToken(node.functionKeyword, visitor)
		end
		if node.openGenerics then
			visitToken(node.openGenerics, visitor)
		end
		visitPunctuated(node.generics, visitor, visitGeneric)
		visitPunctuated(node.genericPacks, visitor, visitGenericPack)
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor)
		end
		visitToken(node.openParens, visitor)
		visitPunctuated(node.parameters, visitor, visitLocal)
		if node.hasVararg then
			assert(node.vararg)
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
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
		visitor.visitExprFunctionEnd(node)
	end
end

local function visitExprInstantiate(node: types.CstExprInstantiate, visitor: Visitor)
	if visitor.visitExprInstantiate(node) then
		visitExpr(node.expr, visitor)
		visitToken(node.leftArrow1, visitor)
		visitToken(node.leftArrow2, visitor)
		visitPunctuated(node.typeArguments, visitor, visitTypeOrTypePack)
		visitToken(node.rightArrow1, visitor)
		visitToken(node.rightArrow2, visitor)
	end
end

local function visitStatFunction(node: types.CstStatFunction, visitor: Visitor)
	if visitor.visitStatFunction(node) then
		-- We need to visit in lexical order
		for _, attribute in node.func.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.func.functionKeyword, visitor)
		visitExpr(node.name, visitor)
		visitExprFunction(node.func, visitor, false, false)
	end
end

local function visitStatLocalFunction(node: types.CstStatLocalFunction, visitor: Visitor)
	if visitor.visitStatLocalFunction(node) then
		for _, attribute in node.func.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.localKeyword, visitor)
		visitToken(node.func.functionKeyword, visitor)
		visitLocal(node.name, visitor)
		visitExprFunction(node.func, visitor, false, false)
	end
end

local function visitStatTypeFunction(node: types.CstStatTypeFunction, visitor: Visitor)
	if visitor.visitStatTypeFunction(node) then
		if node.isExported then
			assert(node.export)
			visitToken(node.export, visitor)
		end
		visitToken(node.type, visitor)
		visitToken(node.body.functionKeyword, visitor)
		visitToken(node.name, visitor)
		visitExprFunction(node.body, visitor, true, false)
	end
end

local function visitTableExprItem(node: types.CstTableExprItem, visitor: Visitor)
	if visitor.visitTableExprItem(node) then
		if node.kind == "list" then
			visitExpr(node.value, visitor)
		elseif node.kind == "record" then
			visitToken(node.key, visitor)
			visitToken(node.equals, visitor)
			visitExpr(node.value, visitor)
		elseif node.kind == "general" then
			visitToken(node.indexerOpen, visitor)
			visitExpr(node.key, visitor)
			visitToken(node.indexerClose, visitor)
			visitToken(node.equals, visitor)
			visitExpr(node.value, visitor)
		else
			exhaustiveMatch(node.kind)
		end

		if node.separator then
			visitToken(node.separator, visitor)
		end
	end
end

local function visitExprTable(node: types.CstExprTable, visitor: Visitor)
	if visitor.visitExprTable(node) then
		visitToken(node.openBrace, visitor)
		for _, item in node.entries do
			visitTableExprItem(item, visitor)
		end
		visitToken(node.closeBrace, visitor)
	end
end

local function visitExprIndexName(node: types.CstExprIndexName, visitor: Visitor)
	if visitor.visitExprIndexName(node) then
		visitExpr(node.expression, visitor)
		visitToken(node.accessor, visitor)
		visitToken(node.index, visitor)
	end
end

local function visitExprIndexExpr(node: types.CstExprIndexExpr, visitor: Visitor)
	if visitor.visitExprIndexExpr(node) then
		visitExpr(node.expression, visitor)
		visitToken(node.openBrackets, visitor)
		visitExpr(node.index, visitor)
		visitToken(node.closeBrackets, visitor)
	end
end

local function visitExprGroup(node: types.CstExprGroup, visitor: Visitor)
	if visitor.visitExprGroup(node) then
		visitToken(node.openParens, visitor)
		visitExpr(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitExprInterpString(node: types.CstExprInterpString, visitor: Visitor)
	if visitor.visitExprInterpString(node) then
		for i = 1, #node.strings do
			visitToken(node.strings[i], visitor)
			if i <= #node.expressions then
				visitExpr(node.expressions[i], visitor)
			end
		end
	end
end

local function visitExprTypeAssertion(node: types.CstExprTypeAssertion, visitor: Visitor)
	if visitor.visitExprTypeAssertion(node) then
		visitExpr(node.operand, visitor)
		visitToken(node.operator, visitor)
		visitType(node.annotation, visitor)
	end
end

local function visitExprIfElse(node: types.CstExprIfElse, visitor: Visitor)
	if visitor.visitExprIfElse(node) then
		visitToken(node.ifKeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.thenKeyword, visitor)
		visitExpr(node.thenExpr, visitor)
		for _, elseifs in node.elseifs do
			visitToken(elseifs.elseIfKeyword, visitor)
			visitExpr(elseifs.condition, visitor)
			visitToken(elseifs.thenKeyword, visitor)
			visitExpr(elseifs.thenExpr, visitor)
		end
		visitToken(node.elseKeyword, visitor)
		visitExpr(node.elseExpr, visitor)
	end
end

local function visitTypeOrPack(node: types.CstType | types.CstTypePack, visitor: Visitor)
	if node.kind == "typepack" then
		visitTypePack(node, visitor)
	else
		visitType(node, visitor)
	end
end

local function visitTypeReference(node: types.CstTypeReference, visitor: Visitor)
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

local function visitTypeSingletonBool(node: types.CstTypeSingletonBool, visitor: Visitor)
	if visitor.visitTypeSingletonBool(node) then
		visitToken(node.token, visitor)
	end
end

local function visitTypeSingletonString(node: types.CstTypeSingletonString, visitor: Visitor)
	if visitor.visitTypeSingletonString(node) then
		visitToken(node.value, visitor)
	end
end

local function visitTypeTypeof(node: types.CstTypeTypeof, visitor: Visitor)
	if visitor.visitTypeTypeof(node) then
		visitToken(node.typeof, visitor)
		visitToken(node.openParens, visitor)
		visitExpr(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitTypeGroup(node: types.CstTypeGroup, visitor: Visitor)
	if visitor.visitTypeGroup(node) then
		visitToken(node.openParens, visitor)
		visitType(node.type, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitTypeOptional(node: types.CstTypeOptional, visitor: Visitor)
	if visitor.visitTypeOptional(node) then
		visitToken(node.token, visitor)
	end
end

local function visitTypeUnion(node: types.CstTypeUnion, visitor: Visitor)
	if visitor.visitTypeUnion(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeIntersection(node: types.CstTypeIntersection, visitor: Visitor)
	if visitor.visitTypeIntersection(node) then
		if node.leading then
			visitToken(node.leading, visitor)
		end
		visitPunctuated(node.types, visitor, visitType)
	end
end

local function visitTypeArray(node: types.CstTypeArray, visitor: Visitor)
	if visitor.visitTypeArray(node) then
		visitToken(node.openBrace, visitor)
		if node.access then
			visitToken(node.access, visitor)
		end
		visitType(node.type, visitor)
		visitToken(node.closeBrace, visitor)
	end
end

local function visitTypeTable(node: types.CstTypeTable, visitor: Visitor)
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
				visitTypeSingletonString(entry.key, visitor)
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

local function visitFunctionTypeParameter(node: types.CstFunctionTypeParameter, visitor)
	if node.name then
		visitToken(node.name, visitor)
	end
	if node.colon then
		visitToken(node.colon, visitor)
	end
	visitType(node.type, visitor)
end

local function visitTypeFunction(node: types.CstTypeFunction, visitor: Visitor)
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
		visitPunctuated(node.parameters, visitor, visitFunctionTypeParameter)
		if node.vararg then
			visitTypePack(node.vararg, visitor)
		end
		visitToken(node.closeParens, visitor)
		visitToken(node.returnArrow, visitor)
		visitTypePack(node.returnTypes, visitor)
	end
end

local function visitTypePackExplicit(node: types.CstTypePackExplicit, visitor: Visitor)
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

local function visitTypePackGeneric(node: types.CstTypePackGeneric, visitor: Visitor)
	if visitor.visitTypePackGeneric(node) then
		visitToken(node.name, visitor)
		visitToken(node.ellipsis, visitor)
	end
end

local function visitTypePackVariadic(node: types.CstTypePackVariadic, visitor: Visitor)
	if visitor.visitTypePackVariadic(node) then
		if node.ellipsis then
			visitToken(node.ellipsis, visitor)
		end
		visitType(node.type, visitor)
	end
end

function visitExpr(expression: types.CstExpr, visitor: Visitor)
	if visitor.visitExpr(expression) then
		if expression.tag == "nil" then
			visitExprConstantNil(expression, visitor)
		elseif expression.tag == "boolean" then
			visitExprConstantBool(expression, visitor)
		elseif expression.tag == "number" then
			visitExprConstantNumber(expression, visitor)
		elseif expression.tag == "integer" then
			visitExprConstantInteger(expression, visitor)
		elseif expression.tag == "string" then
			visitExprConstantString(expression, visitor)
		elseif expression.tag == "local" then
			visitExprLocal(expression, visitor)
		elseif expression.tag == "global" then
			visitExprGlobal(expression, visitor)
		elseif expression.tag == "vararg" then
			visitExprVarargs(expression, visitor)
		elseif expression.tag == "call" then
			visitExprCall(expression, visitor)
		elseif expression.tag == "unary" then
			visitExprUnary(expression, visitor)
		elseif expression.tag == "binary" then
			visitExprBinary(expression, visitor)
		elseif expression.tag == "function" then
			visitExprFunction(expression, visitor)
		elseif expression.tag == "instantiate" then
			visitExprInstantiate(expression, visitor)
		elseif expression.tag == "table" then
			visitExprTable(expression, visitor)
		elseif expression.tag == "indexname" then
			visitExprIndexName(expression, visitor)
		elseif expression.tag == "index" then
			visitExprIndexExpr(expression, visitor)
		elseif expression.tag == "group" then
			visitExprGroup(expression, visitor)
		elseif expression.tag == "interpolatedstring" then
			visitExprInterpString(expression, visitor)
		elseif expression.tag == "cast" then
			visitExprTypeAssertion(expression, visitor)
		elseif expression.tag == "conditional" then
			visitExprIfElse(expression, visitor)
		else
			exhaustiveMatch(expression.tag)
		end

		visitor.visitExprEnd(expression)
	end
end

function visitStatement(statement: types.CstStat, visitor: Visitor)
	if statement.tag == "block" then
		visitStatBlock(statement, visitor)
	elseif statement.tag == "do" then
		visitStatDo(statement, visitor)
	elseif statement.tag == "conditional" then
		visitStatIf(statement, visitor)
	elseif statement.tag == "expression" then
		visitStatExpr(statement, visitor)
	elseif statement.tag == "local" then
		visitLocalStatement(statement, visitor)
	elseif statement.tag == "const" then
		visitConstStatement(statement, visitor)
	elseif statement.tag == "return" then
		visitStatReturn(statement, visitor)
	elseif statement.tag == "while" then
		visitStatWhile(statement, visitor)
	elseif statement.tag == "break" then
		visitStatBreak(statement, visitor)
	elseif statement.tag == "continue" then
		visitStatContinue(statement, visitor)
	elseif statement.tag == "repeat" then
		visitStatRepeat(statement, visitor)
	elseif statement.tag == "for" then
		visitStatFor(statement, visitor)
	elseif statement.tag == "forin" then
		visitStatForIn(statement, visitor)
	elseif statement.tag == "assign" then
		visitStatAssign(statement, visitor)
	elseif statement.tag == "compoundassign" then
		visitStatCompoundAssign(statement, visitor)
	elseif statement.tag == "function" then
		visitStatFunction(statement, visitor)
	elseif statement.tag == "localfunction" then
		visitStatLocalFunction(statement, visitor)
	elseif statement.tag == "typealias" then
		visitStatTypeAlias(statement, visitor)
	elseif statement.tag == "typefunction" then
		visitStatTypeFunction(statement, visitor)
	else
		exhaustiveMatch(statement.tag)
	end
end

function visitType(type: types.CstType, visitor: Visitor)
	if type.tag == "reference" then
		visitTypeReference(type, visitor)
	elseif type.tag == "boolean" then
		visitTypeSingletonBool(type, visitor)
	elseif type.tag == "string" then
		visitTypeSingletonString(type, visitor)
	elseif type.tag == "typeof" then
		visitTypeTypeof(type, visitor)
	elseif type.tag == "group" then
		visitTypeGroup(type, visitor)
	elseif type.tag == "union" then
		visitTypeUnion(type, visitor)
	elseif type.tag == "intersection" then
		visitTypeIntersection(type, visitor)
	elseif type.tag == "optional" then
		visitTypeOptional(type, visitor)
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

function visitTypePack(type: types.CstTypePack, visitor: Visitor)
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

--- Creates a `Visitor` where every callback delegates to `visit`. If `visit` is omitted, all callbacks default to visiting every node.
local function create(visit: ((types.CstNode) -> boolean)?): Visitor
	if visit then
		return {
			visitStatBlock = visit,
			visitStatBlockEnd = function(s)
				visit(s)
			end,
			visitStatDo = visit,
			visitStatIf = visit,
			visitStatWhile = visit,
			visitStatRepeat = visit,
			visitStatBreak = visit,
			visitStatContinue = visit,
			visitStatReturn = visit,
			visitStatLocalDeclaration = visit,
			visitStatLocalDeclarationEnd = function(s)
				visit(s)
			end,
			visitStatConstDeclaration = visit,
			visitStatConstDeclarationEnd = function(s)
				visit(s)
			end,
			visitStatFor = visit,
			visitStatForEnd = function(s)
				visit(s)
			end,
			visitStatForIn = visit,
			visitStatForInEnd = function(s)
				visit(s)
			end,
			visitStatAssign = visit,
			visitStatCompoundAssign = visit,
			visitStatFunction = visit,
			visitStatLocalFunction = visit,
			visitStatTypeAlias = visit,
			visitStatTypeFunction = visit,
			visitStatExpr = visit,

			visitExpr = visit,
			visitExprEnd = function(s)
				visit(s)
			end,
			visitExprLocal = visit,
			visitExprGlobal = visit,
			visitExprCall = visit,
			visitExprUnary = visit,
			visitExprBinary = visit,
			visitExprFunction = visit,
			visitExprFunctionEnd = function(s)
				visit(s)
			end,
			visitExprInstantiate = visit,
			visitTableExprItem = visit :: (types.CstTableExprItem) -> boolean,
			visitExprTable = visit,
			visitExprIndexName = visit,
			visitExprIndexExpr = visit,
			visitExprGroup = visit,
			visitExprInterpString = visit,
			visitExprTypeAssertion = visit,
			visitExprIfElse = visit,

			visitTypeReference = visit,
			visitTypeSingletonBool = visit,
			visitTypeSingletonString = visit,
			visitTypeTypeof = visit,
			visitTypeGroup = visit,
			visitTypeOptional = visit,
			visitTypeUnion = visit,
			visitTypeIntersection = visit,
			visitTypeArray = visit,
			visitTypeTable = visit :: (types.CstTypeTable) -> boolean, -- LUAUFIX: Remove cast once code too complex no longer emitted
			visitTypeFunction = visit,

			visitTypePackExplicit = visit,
			visitTypePackGeneric = visit,
			visitTypePackVariadic = visit,

			visitToken = visit :: (types.CstToken) -> boolean,
			visitExprConstantNil = visit,
			visitExprConstantString = visit,
			visitExprConstantBool = visit,
			visitExprConstantNumber = visit,
			visitExprConstantInteger = visit,
			visitLocal = visit,
			visitExprVarargs = visit,

			visitAttribute = visit,
			visitSimpleAttribute = visit,
			visitParametrizedAttribute = visit,
			visitAttributeList = visit,
		}
	else
		return table.clone(defaultVisitor)
	end
end

--- Dispatches `node` to the appropriate `visitor` callback based on its `kind`.
local function visit(node: types.CstNode, visitor: Visitor)
	if node.kind == "stat" then
		visitStatement(node, visitor)
	elseif node.kind == "expr" then
		visitExpr(node, visitor)
	elseif node.kind == "type" then
		visitType(node, visitor)
	elseif node.kind == "typepack" then
		visitTypePack(node, visitor)
	elseif node.kind == "local" then
		visitLocal(node, visitor)
	elseif node.kind == "attribute" then
		visitAttribute(node, visitor)
	elseif node.kind == "token" then
		visitToken(node, visitor)
	elseif (node :: types.CstTableExprItem).isTableItem then
		visitTableExprItem(node :: types.CstTableExprItem, visitor)
	else
		exhaustiveMatch(node.kind)
	end
end

--- Creates a `Visitor` where every callback delegates to `visit`. If `visit` is omitted, all callbacks default to visiting every node.
visitorlib.create = create
--- Visits all statements in a block.
visitorlib.visitBlock = visitStatBlock
--- Visits a single statement, dispatching to the appropriate callback.
visitorlib.visitStatement = visitStatement
--- Visits an expression, dispatching to the appropriate callback.
visitorlib.visitExpression = visitExpr
--- Visits a type annotation, dispatching to the appropriate callback.
visitorlib.visitType = visitType
--- Visits a type pack, dispatching to the appropriate callback.
visitorlib.visitTypePack = visitTypePack
--- Visits a single token.
visitorlib.visitToken = visitToken
--- Visits any CST node, dispatching by `node.kind`.
visitorlib.visit = visit

return table.freeze(visitorlib)
