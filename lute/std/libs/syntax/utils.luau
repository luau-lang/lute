local luau = require("@std/luau")

local function selectLocal(n): luau.AstLocal?
	error("Not implemented")
end

local function selectExprGroup(n): luau.AstExprGroup?
	error("Not implemented")
end

local function selectExprConstantNil(n): luau.AstExprConstantNil?
	error("Not implemented")
end

local function selectExprConstantBool(n): luau.AstExprConstantBool?
	error("Not implemented")
end

local function selectExprConstantNumber(n): luau.AstExprConstantNumber?
	error("Not implemented")
end

local function selectExprConstantString(n): luau.AstExprConstantString?
	error("Not implemented")
end

local function selectExprLocal(n): luau.AstExprLocal?
	error("Not implemented")
end

local function selectExprGlobal(n): luau.AstExprGlobal?
	error("Not implemented")
end

local function selectExprVarargs(n): luau.AstExprVarargs?
	error("Not implemented")
end

local function selectExprCall(n): luau.AstExprCall?
	error("Not implemented")
end

local function selectExprIndexName(n): luau.AstExprIndexName?
	error("Not implemented")
end

local function selectExprIndexExpr(n): luau.AstExprIndexExpr?
	error("Not implemented")
end

local function selectFunctionBody(n): luau.AstFunctionBody?
	error("Not implemented")
end

local function selectExprAnonymousFunction(n): luau.AstExprAnonymousFunction?
	error("Not implemented")
end

local function selectExprTableItem(n): luau.AstExprTableItem?
	error("Not implemented")
end

local function selectExprTable(n): luau.AstExprTable?
	error("Not implemented")
end

local function selectExprUnary(n): luau.AstExprUnary?
	error("Not implemented")
end

local function selectExprBinary(n): luau.AstExprBinary?
	error("Not implemented")
end

local function selectExprInterpString(n): luau.AstExprInterpString?
	error("Not implemented")
end

local function selectExprTypeAssertion(n): luau.AstExprTypeAssertion?
	error("Not implemented")
end

local function selectExprIfElseIfs(n): luau.AstExprIfElseIfs?
	error("Not implemented")
end

local function selectExprIfElse(n): luau.AstExprIfElse?
	error("Not implemented")
end

local function selectExpr(n): luau.AstExpr?
	error("Not implemented")
end

local function selectStatBlock(n): luau.AstStatBlock?
	error("Not implemented")
end

local function selectStatElseIf(n): luau.AstStatElseIf?
	error("Not implemented")
end

local function selectStatIf(n): luau.AstStatIf?
	error("Not implemented")
end

local function selectStatWhile(n): luau.AstStatWhile?
	error("Not implemented")
end

local function selectStatRepeat(n): luau.AstStatRepeat?
	error("Not implemented")
end

local function selectStatBreak(n): luau.AstStatBreak?
	error("Not implemented")
end

local function selectStatContinue(n): luau.AstStatContinue?
	error("Not implemented")
end

local function selectStatReturn(n): luau.AstStatReturn?
	error("Not implemented")
end

local function selectStatExpr(n): luau.AstStatExpr?
	error("Not implemented")
end

local function selectStatLocal(n): luau.AstStatLocal?
	error("Not implemented")
end

local function selectStatFor(n): luau.AstStatFor?
	error("Not implemented")
end

local function selectStatForIn(n): luau.AstStatForIn?
	error("Not implemented")
end

local function selectStatAssign(n): luau.AstStatAssign?
	error("Not implemented")
end

local function selectStatCompoundAssign(n): luau.AstStatCompoundAssign?
	error("Not implemented")
end

local function selectAttribute(n): luau.AstAttribute?
	error("Not implemented")
end

local function selectStatFunction(n): luau.AstStatFunction?
	error("Not implemented")
end

local function selectStatLocalFunction(n): luau.AstStatLocalFunction?
	error("Not implemented")
end

local function selectStatTypeAlias(n): luau.AstStatTypeAlias?
	error("Not implemented")
end

local function selectStatTypeFunction(n): luau.AstStatTypeFunction?
	error("Not implemented")
end

local function selectStat(n): luau.AstStat?
	error("Not implemented")
end

local function selectGenericType(n): luau.AstGenericType?
	error("Not implemented")
end

local function selectGenericTypePack(n): luau.AstGenericTypePack?
	error("Not implemented")
end

local function selectTypeReference(n): luau.AstTypeReference?
	error("Not implemented")
end

local function selectTypeSingletonBool(n): luau.AstTypeSingletonBool?
	error("Not implemented")
end

local function selectTypeSingletonString(n): luau.AstTypeSingletonString?
	error("Not implemented")
end

local function selectTypeTypeof(n): luau.AstTypeTypeof?
	error("Not implemented")
end

local function selectTypeGroup(n): luau.AstTypeGroup?
	error("Not implemented")
end

local function selectTypeOptional(n): luau.AstTypeOptional?
	error("Not implemented")
end

local function selectTypeUnion(n): luau.AstTypeUnion?
	error("Not implemented")
end

local function selectTypeIntersection(n): luau.AstTypeIntersection?
	error("Not implemented")
end

local function selectTypeArray(n): luau.AstTypeArray?
	error("Not implemented")
end

local function selectTypeTableItem(n): luau.AstTypeTableItem?
	error("Not implemented")
end

local function selectTypeTable(n): luau.AstTypeTable?
	error("Not implemented")
end

local function selectTypeFunctionParameter(n): luau.AstTypeFunctionParameter?
	error("Not implemented")
end

local function selectTypeFunction(n): luau.AstTypeFunction?
	error("Not implemented")
end

local function selectType(n): luau.AstType?
	error("Not implemented")
end

local function selectTypePackExplicit(n): luau.AstTypePackExplicit?
	error("Not implemented")
end

local function selectTypePackVariadic(n): luau.AstTypePackVariadic?
	error("Not implemented")
end

local function selectTypePack(n): luau.AstTypePack?
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
