local luau = require("@std/luau")

local function selectLocal(n: luau.AstNode): luau.AstLocal?
	error("Not implemented")
end

local function selectExprGroup(n: luau.AstNode): luau.AstExprGroup?
	error("Not implemented")
end

local function selectExprConstantNil(n: luau.AstNode): luau.AstExprConstantNil?
	error("Not implemented")
end

local function selectExprConstantBool(n: luau.AstNode): luau.AstExprConstantBool?
	error("Not implemented")
end

local function selectExprConstantNumber(n: luau.AstNode): luau.AstExprConstantNumber?
	error("Not implemented")
end

local function selectExprConstantString(n: luau.AstNode): luau.AstExprConstantString?
	error("Not implemented")
end

local function selectExprLocal(n: luau.AstNode): luau.AstExprLocal?
	error("Not implemented")
end

local function selectExprGlobal(n: luau.AstNode): luau.AstExprGlobal?
	error("Not implemented")
end

local function selectExprVarargs(n: luau.AstNode): luau.AstExprVarargs?
	error("Not implemented")
end

local function selectExprCall(n: luau.AstNode): luau.AstExprCall?
	error("Not implemented")
end

local function selectExprIndexName(n: luau.AstNode): luau.AstExprIndexName?
	error("Not implemented")
end

local function selectExprIndexExpr(n: luau.AstNode): luau.AstExprIndexExpr?
	error("Not implemented")
end

local function selectFunctionBody(n: luau.AstNode): luau.AstFunctionBody?
	error("Not implemented")
end

local function selectExprAnonymousFunction(n: luau.AstNode): luau.AstExprAnonymousFunction?
	error("Not implemented")
end

local function selectExprTableItem(n: luau.AstNode): luau.AstExprTableItem?
	error("Not implemented")
end

local function selectExprTable(n: luau.AstNode): luau.AstExprTable?
	error("Not implemented")
end

local function selectExprUnary(n: luau.AstNode): luau.AstExprUnary?
	error("Not implemented")
end

local function selectExprBinary(n: luau.AstNode): luau.AstExprBinary?
	error("Not implemented")
end

local function selectExprInterpString(n: luau.AstNode): luau.AstExprInterpString?
	error("Not implemented")
end

local function selectExprTypeAssertion(n: luau.AstNode): luau.AstExprTypeAssertion?
	error("Not implemented")
end

local function selectExprIfElseIfs(n: luau.AstNode): luau.AstExprIfElseIfs?
	error("Not implemented")
end

local function selectExprIfElse(n: luau.AstNode): luau.AstExprIfElse?
	error("Not implemented")
end

local function selectExpr(n: luau.AstNode): luau.AstExpr?
	error("Not implemented")
end

local function selectStatBlock(n: luau.AstNode): luau.AstStatBlock?
	error("Not implemented")
end

local function selectStatElseIf(n: luau.AstNode): luau.AstStatElseIf?
	error("Not implemented")
end

local function selectStatIf(n: luau.AstNode): luau.AstStatIf?
	error("Not implemented")
end

local function selectStatWhile(n: luau.AstNode): luau.AstStatWhile?
	error("Not implemented")
end

local function selectStatRepeat(n: luau.AstNode): luau.AstStatRepeat?
	error("Not implemented")
end

local function selectStatBreak(n: luau.AstNode): luau.AstStatBreak?
	error("Not implemented")
end

local function selectStatContinue(n: luau.AstNode): luau.AstStatContinue?
	error("Not implemented")
end

local function selectStatReturn(n: luau.AstNode): luau.AstStatReturn?
	error("Not implemented")
end

local function selectStatExpr(n: luau.AstNode): luau.AstStatExpr?
	error("Not implemented")
end

local function selectStatLocal(n: luau.AstNode): luau.AstStatLocal?
	error("Not implemented")
end

local function selectStatFor(n: luau.AstNode): luau.AstStatFor?
	error("Not implemented")
end

local function selectStatForIn(n: luau.AstNode): luau.AstStatForIn?
	error("Not implemented")
end

local function selectStatAssign(n: luau.AstNode): luau.AstStatAssign?
	error("Not implemented")
end

local function selectStatCompoundAssign(n: luau.AstNode): luau.AstStatCompoundAssign?
	error("Not implemented")
end

local function selectAttribute(n: luau.AstNode): luau.AstAttribute?
	error("Not implemented")
end

local function selectStatFunction(n: luau.AstNode): luau.AstStatFunction?
	error("Not implemented")
end

local function selectStatLocalFunction(n: luau.AstNode): luau.AstStatLocalFunction?
	error("Not implemented")
end

local function selectStatTypeAlias(n: luau.AstNode): luau.AstStatTypeAlias?
	error("Not implemented")
end

local function selectStatTypeFunction(n: luau.AstNode): luau.AstStatTypeFunction?
	error("Not implemented")
end

local function selectStat(n: luau.AstNode): luau.AstStat?
	error("Not implemented")
end

local function selectGenericType(n: luau.AstNode): luau.AstGenericType?
	error("Not implemented")
end

local function selectGenericTypePack(n: luau.AstNode): luau.AstGenericTypePack?
	error("Not implemented")
end

local function selectTypeReference(n: luau.AstNode): luau.AstTypeReference?
	error("Not implemented")
end

local function selectTypeSingletonBool(n: luau.AstNode): luau.AstTypeSingletonBool?
	error("Not implemented")
end

local function selectTypeSingletonString(n: luau.AstNode): luau.AstTypeSingletonString?
	error("Not implemented")
end

local function selectTypeTypeof(n: luau.AstNode): luau.AstTypeTypeof?
	error("Not implemented")
end

local function selectTypeGroup(n: luau.AstNode): luau.AstTypeGroup?
	error("Not implemented")
end

local function selectTypeOptional(n: luau.AstNode): luau.AstTypeOptional?
	error("Not implemented")
end

local function selectTypeUnion(n: luau.AstNode): luau.AstTypeUnion?
	error("Not implemented")
end

local function selectTypeIntersection(n: luau.AstNode): luau.AstTypeIntersection?
	error("Not implemented")
end

local function selectTypeArray(n: luau.AstNode): luau.AstTypeArray?
	error("Not implemented")
end

local function selectTypeTableItem(n: luau.AstNode): luau.AstTypeTableItem?
	error("Not implemented")
end

local function selectTypeTable(n: luau.AstNode): luau.AstTypeTable?
	error("Not implemented")
end

local function selectTypeFunctionParameter(n: luau.AstNode): luau.AstTypeFunctionParameter?
	error("Not implemented")
end

local function selectTypeFunction(n: luau.AstNode): luau.AstTypeFunction?
	error("Not implemented")
end

local function selectType(n: luau.AstNode): luau.AstType?
	error("Not implemented")
end

local function selectTypePackExplicit(n: luau.AstNode): luau.AstTypePackExplicit?
	error("Not implemented")
end

local function selectTypePackVariadic(n: luau.AstNode): luau.AstTypePackVariadic?
	error("Not implemented")
end

local function selectTypePack(n: luau.AstNode): luau.AstTypePack?
	error("Not implemented")
end

return {
	selectLocal = selectLocal,
	selectExprGroup = selectExprGroup,
	selectExprConstantNil = selectExprConstantNil,
	selectExprConstantBool = selectExprConstantBool,
	selectExprConstantNumber = selectExprConstantNumber,
	selectExprConstantString = selectExprConstantString,
	selectExprLocal = selectExprLocal,
	selectExprGlobal = selectExprGlobal,
	selectExprVarargs = selectExprVarargs,
	selectExprCall = selectExprCall,
	selectExprIndexName = selectExprIndexName,
	selectExprIndexExpr = selectExprIndexExpr,
	selectFunctionBody = selectFunctionBody,
	selectExprAnonymousFunction = selectExprAnonymousFunction,
	selectExprTableItem = selectExprTableItem,
	selectExprTable = selectExprTable,
	selectExprUnary = selectExprUnary,
	selectExprBinary = selectExprBinary,
	selectExprInterpString = selectExprInterpString,
	selectExprTypeAssertion = selectExprTypeAssertion,
	selectExprIfElseIfs = selectExprIfElseIfs,
	selectExprIfElse = selectExprIfElse,
	selectExpr = selectExpr,
	selectStatBlock = selectStatBlock,
	selectStatElseIf = selectStatElseIf,
	selectStatIf = selectStatIf,
	selectStatWhile = selectStatWhile,
	selectStatRepeat = selectStatRepeat,
	selectStatBreak = selectStatBreak,
	selectStatContinue = selectStatContinue,
	selectStatReturn = selectStatReturn,
	selectStatExpr = selectStatExpr,
	selectStatLocal = selectStatLocal,
	selectStatFor = selectStatFor,
	selectStatForIn = selectStatForIn,
	selectStatAssign = selectStatAssign,
	selectStatCompoundAssign = selectStatCompoundAssign,
	selectAttribute = selectAttribute,
	selectStatFunction = selectStatFunction,
	selectStatLocalFunction = selectStatLocalFunction,
	selectStatTypeAlias = selectStatTypeAlias,
	selectStatTypeFunction = selectStatTypeFunction,
	selectStat = selectStat,
	selectGenericType = selectGenericType,
	selectGenericTypePack = selectGenericTypePack,
	selectTypeReference = selectTypeReference,
	selectTypeSingletonBool = selectTypeSingletonBool,
	selectTypeSingletonString = selectTypeSingletonString,
	selectTypeTypeof = selectTypeTypeof,
	selectTypeGroup = selectTypeGroup,
	selectTypeOptional = selectTypeOptional,
	selectTypeUnion = selectTypeUnion,
	selectTypeIntersection = selectTypeIntersection,
	selectTypeArray = selectTypeArray,
	selectTypeTableItem = selectTypeTableItem,
	selectTypeTable = selectTypeTable,
	selectTypeFunctionParameter = selectTypeFunctionParameter,
	selectTypeFunction = selectTypeFunction,
	selectType = selectType,
	selectTypePackExplicit = selectTypePackExplicit,
	selectTypePackVariadic = selectTypePackVariadic,
	selectTypePack = selectTypePack,
}
