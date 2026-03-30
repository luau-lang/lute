--!strict
-- @std/syntax/visitor
-- Visitor pattern implementation for traversing Luau AST nodes

local types = require("./types")

local visitorlib = {}

export type Visitor = {
	visitStatBlock: (types.AstStatBlock) -> boolean,
	visitStatBlockEnd: (types.AstStatBlock) -> (),
	visitStatDo: (types.AstStatDo) -> boolean,
	visitStatIf: (types.AstStatIf) -> boolean,
	visitStatWhile: (types.AstStatWhile) -> boolean,
	visitStatRepeat: (types.AstStatRepeat) -> boolean,
	visitStatBreak: (types.AstStatBreak) -> boolean,
	visitStatContinue: (types.AstStatContinue) -> boolean,
	visitStatReturn: (types.AstStatReturn) -> boolean,
	visitStatLocalDeclaration: (types.AstStatLocal) -> boolean,
	visitStatLocalDeclarationEnd: (types.AstStatLocal) -> (),
	visitStatFor: (types.AstStatFor) -> boolean,
	visitStatForEnd: (types.AstStatFor) -> (),
	visitStatForIn: (types.AstStatForIn) -> boolean,
	visitStatForInEnd: (types.AstStatForIn) -> (),
	visitStatAssign: (types.AstStatAssign) -> boolean,
	visitStatCompoundAssign: (types.AstStatCompoundAssign) -> boolean,
	visitStatFunction: (types.AstStatFunction) -> boolean,
	visitStatLocalFunction: (types.AstStatLocalFunction) -> boolean,
	visitStatTypeAlias: (types.AstStatTypeAlias) -> boolean,
	visitStatTypeFunction: (types.AstStatTypeFunction) -> boolean,
	visitStatExpr: (types.AstStatExpr) -> boolean,

	visitExpr: (types.AstExpr) -> boolean,
	visitExprEnd: (types.AstExpr) -> (),
	visitExprConstantNil: (types.AstExprConstantNil) -> boolean,
	visitExprConstantString: (types.AstExprConstantString) -> boolean,
	visitExprConstantBool: (types.AstExprConstantBool) -> boolean,
	visitExprConstantNumber: (types.AstExprConstantNumber) -> boolean,
	visitExprLocal: (types.AstExprLocal) -> boolean,
	visitExprGlobal: (types.AstExprGlobal) -> boolean,
	visitExprCall: (types.AstExprCall) -> boolean,
	visitExprUnary: (types.AstExprUnary) -> boolean,
	visitExprBinary: (types.AstExprBinary) -> boolean,
	visitExprFunction: (types.AstExprFunction) -> boolean,
	visitExprFunctionEnd: (types.AstExprFunction) -> (),
	visitExprInstantiate: (types.AstExprInstantiate) -> boolean,
	visitTableExprItem: (types.AstTableExprItem) -> boolean,
	visitExprTable: (types.AstExprTable) -> boolean,
	visitExprIndexName: (types.AstExprIndexName) -> boolean,
	visitExprIndexExpr: (types.AstExprIndexExpr) -> boolean,
	visitExprGroup: (types.AstExprGroup) -> boolean,
	visitExprInterpString: (types.AstExprInterpString) -> boolean,
	visitExprTypeAssertion: (types.AstExprTypeAssertion) -> boolean,
	visitExprIfElse: (types.AstExprIfElse) -> boolean,
	visitExprVarargs: (types.AstExprVarargs) -> boolean,

	visitTypeReference: (types.AstTypeReference) -> boolean,
	visitTypeSingletonBool: (types.AstTypeSingletonBool) -> boolean,
	visitTypeSingletonString: (types.AstTypeSingletonString) -> boolean,
	visitTypeTypeof: (types.AstTypeTypeof) -> boolean,
	visitTypeGroup: (types.AstTypeGroup) -> boolean,
	visitTypeOptional: (types.AstTypeOptional) -> boolean,
	visitTypeUnion: (types.AstTypeUnion) -> boolean,
	visitTypeIntersection: (types.AstTypeIntersection) -> boolean,
	visitTypeArray: (types.AstTypeArray) -> boolean,
	visitTypeTable: (types.AstTypeTable) -> boolean,
	visitTypeFunction: (types.AstTypeFunction) -> boolean,

	visitTypePackExplicit: (types.AstTypePackExplicit) -> boolean,
	visitTypePackGeneric: (types.AstTypePackGeneric) -> boolean,
	visitTypePackVariadic: (types.AstTypePackVariadic) -> boolean,

	visitToken: (types.Token) -> boolean,

	visitLocal: (types.AstLocal) -> boolean,

	visitAttribute: (types.AstAttribute) -> boolean,
}

local function alwaysVisit(...: types.AstNode)
	return true
end

local defaultVisitor: Visitor = {
	visitStatBlock = alwaysVisit,
	visitStatBlockEnd = alwaysVisit :: (types.AstNode) -> (),
	visitStatDo = alwaysVisit,
	visitStatIf = alwaysVisit,
	visitStatWhile = alwaysVisit,
	visitStatRepeat = alwaysVisit,
	visitStatBreak = alwaysVisit,
	visitStatContinue = alwaysVisit,
	visitStatReturn = alwaysVisit,
	visitStatLocalDeclaration = alwaysVisit,
	visitStatLocalDeclarationEnd = alwaysVisit :: (types.AstNode) -> (),
	visitStatFor = alwaysVisit,
	visitStatForEnd = alwaysVisit :: (types.AstNode) -> (),
	visitStatForIn = alwaysVisit,
	visitStatForInEnd = alwaysVisit :: (types.AstNode) -> (),
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
	visitExprEnd = alwaysVisit :: (types.AstNode) -> (),
	visitExprLocal = alwaysVisit,
	visitExprGlobal = alwaysVisit,
	visitExprCall = alwaysVisit,
	visitExprUnary = alwaysVisit,
	visitExprBinary = alwaysVisit,
	visitExprFunction = alwaysVisit,
	visitExprFunctionEnd = alwaysVisit :: (types.AstNode) -> (),
	visitExprInstantiate = alwaysVisit,
	visitTableExprItem = alwaysVisit :: (types.AstTableExprItem) -> boolean,
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
	visitTypeTable = alwaysVisit :: (types.AstTypeTable) -> boolean, -- LUAUFIX: Code too complex emitted in absence of cast
	visitTypeFunction = alwaysVisit,

	visitTypePackExplicit = alwaysVisit,
	visitTypePackGeneric = alwaysVisit,
	visitTypePackVariadic = alwaysVisit,

	visitToken = alwaysVisit,

	visitLocal = alwaysVisit,

	visitAttribute = alwaysVisit,
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

local function visitTypeOrTypePack(node: types.AstType | types.AstTypePack, visitor: Visitor)
	if node.kind == "type" then
		visitType(node, visitor)
	else
		visitTypePack(node, visitor)
	end
end

local function visitStatBlock(block: types.AstStatBlock, visitor: Visitor)
	if visitor.visitStatBlock(block) then
		for _, statement in block.statements do
			visitStatement(statement, visitor)
		end

		visitor.visitStatBlockEnd(block)
	end
end

local function visitStatDo(node: types.AstStatDo, visitor: Visitor)
	if visitor.visitStatDo(node) then
		visitToken(node.dokeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endkeyword, visitor)
	end
end

local function visitStatIf(node: types.AstStatIf, visitor: Visitor)
	if visitor.visitStatIf(node) then
		visitToken(node.ifkeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.thenkeyword, visitor)
		visitStatBlock(node.thenblock, visitor)
		for _, elseifNode in node.elseifs do
			visitToken(elseifNode.elseifkeyword, visitor)
			visitExpr(elseifNode.condition, visitor)
			visitToken(elseifNode.thenkeyword, visitor)
			visitStatBlock(elseifNode.thenblock, visitor)
		end
		if node.elsekeyword then
			visitToken(node.elsekeyword, visitor)
		end
		if node.elseblock then
			visitStatBlock(node.elseblock, visitor)
		end
		visitToken(node.endkeyword, visitor)
	end
end

local function visitStatWhile(node: types.AstStatWhile, visitor: Visitor)
	if visitor.visitStatWhile(node) then
		visitToken(node.whilekeyword, visitor)
		visitExpr(node.condition, visitor)
		visitToken(node.dokeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endkeyword, visitor)
	end
end

local function visitStatRepeat(node: types.AstStatRepeat, visitor: Visitor)
	if visitor.visitStatRepeat(node) then
		visitToken(node.repeatkeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.untilkeyword, visitor)
		visitExpr(node.condition, visitor)
	end
end

local function visitStatBreak(node: types.AstStatBreak, visitor: Visitor)
	if visitor.visitStatBreak(node) then
		visitToken(node.token, visitor)
	end
end

local function visitStatContinue(node: types.AstStatContinue, visitor: Visitor)
	if visitor.visitStatContinue(node) then
		visitToken(node.token, visitor)
	end
end

local function visitStatReturn(node: types.AstStatReturn, visitor: Visitor)
	if visitor.visitStatReturn(node) then
		visitToken(node.returnkeyword, visitor)
		visitPunctuated(node.expressions, visitor, visitExpr)
	end
end

local function visitLocalStatement(node: types.AstStatLocal, visitor: Visitor)
	if visitor.visitStatLocalDeclaration(node) then
		visitToken(node.localkeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		if node.equals then
			visitToken(node.equals, visitor)
		end
		visitPunctuated(node.values, visitor, visitExpr)

		visitor.visitStatLocalDeclarationEnd(node)
	end
end

local function visitStatFor(node: types.AstStatFor, visitor: Visitor)
	if visitor.visitStatFor(node) then
		visitToken(node.forkeyword, visitor)
		visitLocal(node.variable, visitor)
		visitToken(node.equals, visitor)
		visitExpr(node.from, visitor)
		visitToken(node.tocomma, visitor)
		visitExpr(node.to, visitor)
		if node.stepcomma then
			visitToken(node.stepcomma, visitor)
		end
		if node.step then
			visitExpr(node.step, visitor)
		end
		visitToken(node.dokeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endkeyword, visitor)
		visitor.visitStatForEnd(node)
	end
end

local function visitStatForIn(node: types.AstStatForIn, visitor: Visitor)
	if visitor.visitStatForIn(node) then
		visitToken(node.forkeyword, visitor)
		visitPunctuated(node.variables, visitor, visitLocal)
		visitToken(node.inkeyword, visitor)
		visitPunctuated(node.values, visitor, visitExpr)
		visitToken(node.dokeyword, visitor)
		visitStatBlock(node.body, visitor)
		visitToken(node.endkeyword, visitor)
		visitor.visitStatForInEnd(node)
	end
end

local function visitStatAssign(node: types.AstStatAssign, visitor: Visitor)
	if visitor.visitStatAssign(node) then
		visitPunctuated(node.variables, visitor, visitExpr)
		visitToken(node.equals, visitor)
		visitPunctuated(node.values, visitor, visitExpr)
	end
end

local function visitStatCompoundAssign(node: types.AstStatCompoundAssign, visitor: Visitor)
	if visitor.visitStatCompoundAssign(node) then
		visitExpr(node.variable, visitor)
		visitToken(node.operand, visitor)
		visitExpr(node.value, visitor)
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

local function visitStatTypeAlias(node: types.AstStatTypeAlias, visitor: Visitor)
	if visitor.visitStatTypeAlias(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.typetoken, visitor)
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

local function visitStatExpr(node: types.AstStatExpr, visitor: Visitor)
	if visitor.visitStatExpr(node) then
		visitExpr(node.expression, visitor)
	end
end

local function visitExprConstantString(node: types.AstExprConstantString, visitor: Visitor)
	if visitor.visitExprConstantString(node) then
		visitor.visitToken(node.token)
	end
end

local function visitExprConstantNil(node: types.AstExprConstantNil, visitor: Visitor)
	if visitor.visitExprConstantNil(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprConstantBool(node: types.AstExprConstantBool, visitor: Visitor)
	if visitor.visitExprConstantBool(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprConstantNumber(node: types.AstExprConstantNumber, visitor: Visitor)
	if visitor.visitExprConstantNumber(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprLocal(node: types.AstExprLocal, visitor: Visitor)
	if visitor.visitExprLocal(node) then
		visitor.visitToken(node.token)
	end
end

local function visitExprGlobal(node: types.AstExprGlobal, visitor: Visitor)
	if visitor.visitExprGlobal(node) then
		visitor.visitToken(node.name)
	end
end

local function visitExprVarargs(node: types.AstExprVarargs, visitor: Visitor)
	if visitor.visitExprVarargs(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprCall(node: types.AstExprCall, visitor: Visitor)
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

local function visitExprUnary(node: types.AstExprUnary, visitor: Visitor)
	if visitor.visitExprUnary(node) then
		visitToken(node.operator, visitor)
		visitExpr(node.operand, visitor)
	end
end

local function visitExprBinary(node: types.AstExprBinary, visitor: Visitor)
	if visitor.visitExprBinary(node) then
		visitExpr(node.lhsOperand, visitor)
		visitToken(node.operator, visitor)
		visitExpr(node.rhsOperand, visitor)
	end
end

local function visitAttribute(node: types.AstAttribute, visitor: Visitor)
	if visitor.visitAttribute(node) then
		visitToken(node.token, visitor)
	end
end

local function visitExprFunction(
	node: types.AstExprFunction,
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
		visitStatBlock(node.body, visitor)
		visitToken(node.endKeyword, visitor)
		visitor.visitExprFunctionEnd(node)
	end
end

local function visitExprInstantiate(node: types.AstExprInstantiate, visitor: Visitor)
	if visitor.visitExprInstantiate(node) then
		visitExpr(node.expr, visitor)
		visitToken(node.leftArrow1, visitor)
		visitToken(node.leftArrow2, visitor)
		visitPunctuated(node.typeArguments, visitor, visitTypeOrTypePack)
		visitToken(node.rightArrow1, visitor)
		visitToken(node.rightArrow2, visitor)
	end
end

local function visitStatFunction(node: types.AstStatFunction, visitor: Visitor)
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

local function visitStatLocalFunction(node: types.AstStatLocalFunction, visitor: Visitor)
	if visitor.visitStatLocalFunction(node) then
		for _, attribute in node.func.attributes do
			visitAttribute(attribute, visitor)
		end
		visitToken(node.localkeyword, visitor)
		visitToken(node.func.functionKeyword, visitor)
		visitLocal(node.name, visitor)
		visitExprFunction(node.func, visitor, false, false)
	end
end

local function visitStatTypeFunction(node: types.AstStatTypeFunction, visitor: Visitor)
	if visitor.visitStatTypeFunction(node) then
		if node.export then
			visitToken(node.export, visitor)
		end
		visitToken(node.type, visitor)
		visitToken(node.body.functionKeyword, visitor)
		visitToken(node.name, visitor)
		visitExprFunction(node.body, visitor, true, false)
	end
end

local function visitTableExprItem(node: types.AstTableExprItem, visitor: Visitor)
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

local function visitExprTable(node: types.AstExprTable, visitor: Visitor)
	if visitor.visitExprTable(node) then
		visitToken(node.openBrace, visitor)
		for _, item in node.entries do
			visitTableExprItem(item, visitor)
		end
		visitToken(node.closeBrace, visitor)
	end
end

local function visitExprIndexName(node: types.AstExprIndexName, visitor: Visitor)
	if visitor.visitExprIndexName(node) then
		visitExpr(node.expression, visitor)
		visitToken(node.accessor, visitor)
		visitToken(node.index, visitor)
	end
end

local function visitExprIndexExpr(node: types.AstExprIndexExpr, visitor: Visitor)
	if visitor.visitExprIndexExpr(node) then
		visitExpr(node.expression, visitor)
		visitToken(node.openBrackets, visitor)
		visitExpr(node.index, visitor)
		visitToken(node.closeBrackets, visitor)
	end
end

local function visitExprGroup(node: types.AstExprGroup, visitor: Visitor)
	if visitor.visitExprGroup(node) then
		visitToken(node.openParens, visitor)
		visitExpr(node.expression, visitor)
		visitToken(node.closeParens, visitor)
	end
end

local function visitExprInterpString(node: types.AstExprInterpString, visitor: Visitor)
	if visitor.visitExprInterpString(node) then
		for i = 1, #node.strings do
			visitToken(node.strings[i], visitor)
			if i <= #node.expressions then
				visitExpr(node.expressions[i], visitor)
			end
		end
	end
end

local function visitExprTypeAssertion(node: types.AstExprTypeAssertion, visitor: Visitor)
	if visitor.visitExprTypeAssertion(node) then
		visitExpr(node.operand, visitor)
		visitToken(node.operator, visitor)
		visitType(node.annotation, visitor)
	end
end

local function visitExprIfElse(node: types.AstExprIfElse, visitor: Visitor)
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

local function visitTypeSingletonBool(node: types.AstTypeSingletonBool, visitor: Visitor)
	if visitor.visitTypeSingletonBool(node) then
		visitToken(node.token, visitor)
	end
end

local function visitTypeSingletonString(node: types.AstTypeSingletonString, visitor: Visitor)
	if visitor.visitTypeSingletonString(node) then
		visitToken(node.token, visitor)
	end
end

local function visitTypeTypeof(node: types.AstTypeTypeof, visitor: Visitor)
	if visitor.visitTypeTypeof(node) then
		visitToken(node.typeof, visitor)
		visitToken(node.openparens, visitor)
		visitExpr(node.expression, visitor)
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

local function visitTypeOptional(node: types.AstTypeOptional, visitor: Visitor)
	if visitor.visitTypeOptional(node) then
		visitToken(node.token, visitor)
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
				visitTypeSingletonString(entry.key, visitor)
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

local function visitFunctionTypeParameter(node: types.AstFunctionTypeParameter, visitor)
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
		visitPunctuated(node.parameters, visitor, visitFunctionTypeParameter)
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

function visitExpr(expression: types.AstExpr, visitor: Visitor)
	if visitor.visitExpr(expression) then
		if expression.tag == "nil" then
			visitExprConstantNil(expression, visitor)
		elseif expression.tag == "boolean" then
			visitExprConstantBool(expression, visitor)
		elseif expression.tag == "number" then
			visitExprConstantNumber(expression, visitor)
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

function visitStatement(statement: types.AstStat, visitor: Visitor)
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

function visitType(type: types.AstType, visitor: Visitor)
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
			visitTableExprItem = visit :: (types.AstTableExprItem) -> boolean,
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
			visitTypeTable = visit :: (types.AstTypeTable) -> boolean, -- LUAUFIX: Remove cast once code too complex no longer emitted
			visitTypeFunction = visit,

			visitTypePackExplicit = visit,
			visitTypePackGeneric = visit,
			visitTypePackVariadic = visit,

			visitToken = visit :: (types.Token) -> boolean,
			visitExprConstantNil = visit,
			visitExprConstantString = visit,
			visitExprConstantBool = visit,
			visitExprConstantNumber = visit,
			visitLocal = visit,
			visitExprVarargs = visit,

			visitAttribute = visit,
		}
	else
		return table.clone(defaultVisitor)
	end
end

local function visit(node: types.AstNode, visitor: Visitor)
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
	elseif (node :: types.AstTableExprItem).isTableItem then
		visitTableExprItem(node :: types.AstTableExprItem, visitor)
	else
		exhaustiveMatch(node.kind)
	end
end

visitorlib.create = create
visitorlib.visitblock = visitStatBlock
visitorlib.visitstatement = visitStatement
visitorlib.visitexpression = visitExpr
visitorlib.visittype = visitType
visitorlib.visittypepack = visitTypePack
visitorlib.visittoken = visitToken
visitorlib.visit = visit

return table.freeze(visitorlib)
