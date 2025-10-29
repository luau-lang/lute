local luau = require("@lute/luau")

local function isLocal(n: luau.AstNode): luau.AstLocal?
	return if n.kind == "local" then n :: luau.AstLocal else nil
end

local function isExprGroup(n: luau.AstNode): luau.AstExprGroup?
	return if n.kind == "expr" and (n :: any).tag == "group" then n :: luau.AstExprGroup else nil
end

local function isExprConstantNil(n: luau.AstNode): luau.AstExprConstantNil?
	return if n.kind == "expr" and (n :: any).tag == "nil" then n :: luau.AstExprConstantNil else nil
end

local function isExprConstantBool(n: luau.AstNode): luau.AstExprConstantBool?
	return if n.kind == "expr" and (n :: any).tag == "bool" then n :: luau.AstExprConstantBool else nil
end

local function isExprConstantNumber(n: luau.AstNode): luau.AstExprConstantNumber?
	return if n.kind == "expr" and (n :: any).tag == "number" then n :: luau.AstExprConstantNumber else nil
end

local function isExprConstantString(n: luau.AstNode): luau.AstExprConstantString?
	return if n.kind == "expr" and (n :: any).tag == "string" then n :: luau.AstExprConstantString else nil
end

local function isExprLocal(n: luau.AstNode): luau.AstExprLocal?
	return if n.kind == "expr" and (n :: any).tag == "local" then n :: luau.AstExprLocal else nil
end

local function isExprGlobal(n: luau.AstNode): luau.AstExprGlobal?
	return if n.kind == "expr" and (n :: any).tag == "global" then n :: luau.AstExprGlobal else nil
end

local function isExprVarargs(n: luau.AstNode): luau.AstExprVarargs?
	return if n.kind == "expr" and (n :: any).tag == "vararg" then n :: luau.AstExprVarargs else nil
end

local function isExprCall(n: luau.AstNode): luau.AstExprCall?
	return if n.kind == "expr" and (n :: any).tag == "call" then n :: luau.AstExprCall else nil
end

local function isExprIndexName(n: luau.AstNode): luau.AstExprIndexName?
	return if n.kind == "expr" and (n :: any).tag == "indexname" then n :: luau.AstExprIndexName else nil
end

local function isExprIndexExpr(n: luau.AstNode): luau.AstExprIndexExpr?
	return if n.kind == "expr" and (n :: any).tag == "index" then n :: luau.AstExprIndexExpr else nil
end

local function isExprAnonymousFunction(n: luau.AstNode): luau.AstExprAnonymousFunction?
	return if n.kind == "expr" and (n :: any).tag == "function" then n :: luau.AstExprAnonymousFunction else nil
end

local function isExprTable(n: luau.AstNode): luau.AstExprTable?
	return if n.kind == "expr" and (n :: any).tag == "table" then n :: luau.AstExprTable else nil
end

local function isExprUnary(n: luau.AstNode): luau.AstExprUnary?
	return if n.kind == "expr" and (n :: any).tag == "unary" then n :: luau.AstExprUnary else nil
end

local function isExprBinary(n: luau.AstNode): luau.AstExprBinary?
	return if n.kind == "expr" and (n :: any).tag == "binary" then n :: luau.AstExprBinary else nil
end

local function isExprInterpString(n: luau.AstNode): luau.AstExprInterpString?
	return if n.kind == "expr" and (n :: any).tag == "interpolatedstring" then n :: luau.AstExprInterpString else nil
end

local function isExprTypeAssertion(n: luau.AstNode): luau.AstExprTypeAssertion?
	return if n.kind == "expr" and (n :: any).tag == "cast" then n :: luau.AstExprTypeAssertion else nil
end

local function isExprIfElse(n: luau.AstNode): luau.AstExprIfElse?
	return if n.kind == "expr" and (n :: any).tag == "conditional" then n :: luau.AstExprIfElse else nil
end

local function isExpr(n: luau.AstNode): luau.AstExpr?
	return if n.kind == "expr" then n :: luau.AstExpr else nil
end

local function isStatBlock(n: luau.AstNode): luau.AstStatBlock?
	return if n.kind == "stat" and (n :: any).tag == "block" then n :: luau.AstStatBlock else nil
end

local function isStatIf(n: luau.AstNode): luau.AstStatIf?
	return if n.kind == "stat" and (n :: any).tag == "conditional" then n :: luau.AstStatIf else nil
end

local function isStatWhile(n: luau.AstNode): luau.AstStatWhile?
	return if n.kind == "stat" and (n :: any).tag == "while" then n :: luau.AstStatWhile else nil
end

local function isStatRepeat(n: luau.AstNode): luau.AstStatRepeat?
	return if n.kind == "stat" and (n :: any).tag == "repeat" then n :: luau.AstStatRepeat else nil
end

local function isStatBreak(n: luau.AstNode): luau.AstStatBreak?
	return if n.kind == "stat" and (n :: any).tag == "break" then n :: luau.AstStatBreak else nil
end

local function isStatContinue(n: luau.AstNode): luau.AstStatContinue?
	return if n.kind == "stat" and (n :: any).tag == "continue" then n :: luau.AstStatContinue else nil
end

local function isStatReturn(n: luau.AstNode): luau.AstStatReturn?
	return if n.kind == "stat" and (n :: any).tag == "return" then n :: luau.AstStatReturn else nil
end

local function isStatExpr(n: luau.AstNode): luau.AstStatExpr?
	return if n.kind == "stat" and (n :: any).tag == "expression" then n :: luau.AstStatExpr else nil
end

local function isStatLocal(n: luau.AstNode): luau.AstStatLocal?
	return if n.kind == "stat" and (n :: any).tag == "local" then n :: luau.AstStatLocal else nil
end

local function isStatFor(n: luau.AstNode): luau.AstStatFor?
	return if n.kind == "stat" and (n :: any).tag == "for" then n :: luau.AstStatFor else nil
end

local function isStatForIn(n: luau.AstNode): luau.AstStatForIn?
	return if n.kind == "stat" and (n :: any).tag == "forin" then n :: luau.AstStatForIn else nil
end

local function isStatAssign(n: luau.AstNode): luau.AstStatAssign?
	return if n.kind == "stat" and (n :: any).tag == "assign" then n :: luau.AstStatAssign else nil
end

local function isStatCompoundAssign(n: luau.AstNode): luau.AstStatCompoundAssign?
	return if n.kind == "stat" and (n :: any).tag == "compoundassign" then n :: luau.AstStatCompoundAssign else nil
end

local function isStatFunction(n: luau.AstNode): luau.AstStatFunction?
	return if n.kind == "stat" and (n :: any).tag == "function" then n :: luau.AstStatFunction else nil
end

local function isStatLocalFunction(n: luau.AstNode): luau.AstStatLocalFunction?
	return if n.kind == "stat" and (n :: any).tag == "localfunction" then n :: luau.AstStatLocalFunction else nil
end

local function isStatTypeAlias(n: luau.AstNode): luau.AstStatTypeAlias?
	return if n.kind == "stat" and (n :: any).tag == "typealias" then n :: luau.AstStatTypeAlias else nil
end

local function isStatTypeFunction(n: luau.AstNode): luau.AstStatTypeFunction?
	return if n.kind == "stat" and (n :: any).tag == "typefunction" then n :: luau.AstStatTypeFunction else nil
end

local function isStat(n: luau.AstNode): luau.AstStat?
	return if n.kind == "stat" then (n :: any) :: luau.AstStat else nil
end

local function isGenericType(n: luau.AstNode): luau.AstGenericType?
	return if n.kind == "type" and (n :: any).tag == "generic" then n :: luau.AstGenericType else nil
end

local function isGenericTypePack(n: luau.AstNode): luau.AstGenericTypePack?
	return if n.kind == "typepack" and (n :: any).tag == "genericpack" then n :: luau.AstGenericTypePack else nil
end

local function isTypeReference(n: luau.AstNode): luau.AstTypeReference?
	return if n.kind == "type" and (n :: any).tag == "reference" then n :: luau.AstTypeReference else nil
end

local function isTypeSingletonBool(n: luau.AstNode): luau.AstTypeSingletonBool?
	return if n.kind == "type" and (n :: any).tag == "boolean" then n :: luau.AstTypeSingletonBool else nil
end

local function isTypeSingletonString(n: luau.AstNode): luau.AstTypeSingletonString?
	return if n.kind == "type" and (n :: any).tag == "string" then n :: luau.AstTypeSingletonString else nil
end

local function isTypeTypeof(n: luau.AstNode): luau.AstTypeTypeof?
	return if n.kind == "type" and (n :: any).tag == "typeof" then n :: luau.AstTypeTypeof else nil
end

local function isTypeGroup(n: luau.AstNode): luau.AstTypeGroup?
	return if n.kind == "type" and (n :: any).tag == "group" then n :: luau.AstTypeGroup else nil
end

local function isTypeOptional(n: luau.AstNode): luau.AstTypeOptional?
	return if n.kind == "type" and (n :: any).tag == "optional" then n :: luau.AstTypeOptional else nil
end

local function isTypeUnion(n: luau.AstNode): luau.AstTypeUnion?
	return if n.kind == "type" and (n :: any).tag == "union" then n :: luau.AstTypeUnion else nil
end

local function isTypeIntersection(n: luau.AstNode): luau.AstTypeIntersection?
	return if n.kind == "type" and (n :: any).tag == "intersection" then n :: luau.AstTypeIntersection else nil
end

local function isTypeArray(n: luau.AstNode): luau.AstTypeArray?
	return if n.kind == "type" and (n :: any).tag == "array" then n :: luau.AstTypeArray else nil
end

local function isTypeTable(n: luau.AstNode): luau.AstTypeTable?
	return if n.kind == "type" and (n :: any).tag == "table" then n :: luau.AstTypeTable else nil
end

local function isTypeFunction(n: luau.AstNode): luau.AstTypeFunction?
	return if n.kind == "type" and (n :: any).tag == "function" then n :: luau.AstTypeFunction else nil
end

local function isType(n: luau.AstNode): luau.AstType?
	return if n.kind == "type" then n :: luau.AstType else nil
end

local function isTypePackExplicit(n: luau.AstNode): luau.AstTypePackExplicit?
	return if n.kind == "typepack" and (n :: any).tag == "explicit" then n :: luau.AstTypePackExplicit else nil
end

local function isTypePackVariadic(n: luau.AstNode): luau.AstTypePackVariadic?
	return if n.kind == "typepack" and (n :: any).tag == "variadic" then n :: luau.AstTypePackVariadic else nil
end

local function isTypePackGeneric(n: luau.AstNode): luau.AstTypePackGeneric?
	return if n.kind == "typepack" and (n :: any).tag == "generic" then n :: luau.AstTypePackGeneric else nil
end

local function isTypePack(n: luau.AstNode): luau.AstTypePack?
	return if n.kind == "typepack" then n :: luau.AstTypePack else nil
end

return {
	isLocal = isLocal,
	isExprGroup = isExprGroup,
	isExprConstantNil = isExprConstantNil,
	isExprConstantBool = isExprConstantBool,
	isExprConstantNumber = isExprConstantNumber,
	isExprConstantString = isExprConstantString,
	isExprLocal = isExprLocal,
	isExprGlobal = isExprGlobal,
	isExprVarargs = isExprVarargs,
	isExprCall = isExprCall,
	isExprIndexName = isExprIndexName,
	isExprIndexExpr = isExprIndexExpr,
	isExprAnonymousFunction = isExprAnonymousFunction,
	isExprTable = isExprTable,
	isExprUnary = isExprUnary,
	isExprBinary = isExprBinary,
	isExprInterpString = isExprInterpString,
	isExprTypeAssertion = isExprTypeAssertion,
	isExprIfElse = isExprIfElse,
	isExpr = isExpr,
	isStatBlock = isStatBlock,
	isStatIf = isStatIf,
	isStatWhile = isStatWhile,
	isStatRepeat = isStatRepeat,
	isStatBreak = isStatBreak,
	isStatContinue = isStatContinue,
	isStatReturn = isStatReturn,
	isStatExpr = isStatExpr,
	isStatLocal = isStatLocal,
	isStatFor = isStatFor,
	isStatForIn = isStatForIn,
	isStatAssign = isStatAssign,
	isStatCompoundAssign = isStatCompoundAssign,
	isStatFunction = isStatFunction,
	isStatLocalFunction = isStatLocalFunction,
	isStatTypeAlias = isStatTypeAlias,
	isStatTypeFunction = isStatTypeFunction,
	isStat = isStat,
	isGenericType = isGenericType,
	isGenericTypePack = isGenericTypePack,
	isTypeReference = isTypeReference,
	isTypeSingletonBool = isTypeSingletonBool,
	isTypeSingletonString = isTypeSingletonString,
	isTypeTypeof = isTypeTypeof,
	isTypeGroup = isTypeGroup,
	isTypeOptional = isTypeOptional,
	isTypeUnion = isTypeUnion,
	isTypeIntersection = isTypeIntersection,
	isTypeArray = isTypeArray,
	isTypeTable = isTypeTable,
	isTypeFunction = isTypeFunction,
	isType = isType,
	isTypePackExplicit = isTypePackExplicit,
	isTypePackGeneric = isTypePackGeneric,
	isTypePackVariadic = isTypePackVariadic,
	isTypePack = isTypePack,
}
