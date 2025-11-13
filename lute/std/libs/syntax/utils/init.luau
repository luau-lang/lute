local retriever = require("@self/retriever")
local types = require("./types")

local utils = {}

function utils.isLocal(n: types.AstNode): types.AstLocal?
	return if n.kind == "local" then n else nil
end

function utils.isExprGroup(n: types.AstNode): types.AstExprGroup?
	return if n.kind == "expr" and n.tag == "group" then n else nil
end

function utils.isExprConstantNil(n: types.AstNode): types.AstExprConstantNil?
	return if n.kind == "expr" and n.tag == "nil" then n else nil
end

function utils.isExprConstantBool(n: types.AstNode): types.AstExprConstantBool?
	return if n.kind == "expr" and n.tag == "boolean" then n else nil
end

function utils.isExprConstantNumber(n: types.AstNode): types.AstExprConstantNumber?
	return if n.kind == "expr" and n.tag == "number" then n else nil
end

function utils.isExprConstantString(n: types.AstNode): types.AstExprConstantString?
	return if n.kind == "expr" and n.tag == "string" then n else nil
end

function utils.isExprLocal(n: types.AstNode): types.AstExprLocal?
	return if n.kind == "expr" and n.tag == "local" then n else nil
end

function utils.isExprGlobal(n: types.AstNode): types.AstExprGlobal?
	return if n.kind == "expr" and n.tag == "global" then n else nil
end

function utils.isExprVarargs(n: types.AstNode): types.AstExprVarargs?
	return if n.kind == "expr" and n.tag == "vararg" then n else nil
end

function utils.isExprCall(n: types.AstNode): types.AstExprCall?
	return if n.kind == "expr" and n.tag == "call" then n else nil
end

function utils.isExprIndexName(n: types.AstNode): types.AstExprIndexName?
	return if n.kind == "expr" and n.tag == "indexname" then n else nil
end

function utils.isExprIndexExpr(n: types.AstNode): types.AstExprIndexExpr?
	return if n.kind == "expr" and n.tag == "index" then n else nil
end

function utils.isExprAnonymousFunction(n: types.AstNode): types.AstExprAnonymousFunction?
	return if n.kind == "expr" and n.tag == "function" then n else nil
end

function utils.isExprTable(n: types.AstNode): types.AstExprTable?
	return if n.kind == "expr" and n.tag == "table" then n else nil
end

function utils.isExprUnary(n: types.AstNode): types.AstExprUnary?
	return if n.kind == "expr" and n.tag == "unary" then n else nil
end

function utils.isExprBinary(n: types.AstNode): types.AstExprBinary?
	return if n.kind == "expr" and n.tag == "binary" then n else nil
end

function utils.isExprInterpString(n: types.AstNode): types.AstExprInterpString?
	return if n.kind == "expr" and n.tag == "interpolatedstring" then n else nil
end

function utils.isExprTypeAssertion(n: types.AstNode): types.AstExprTypeAssertion?
	return if n.kind == "expr" and n.tag == "cast" then n else nil
end

function utils.isExprIfElse(n: types.AstNode): types.AstExprIfElse?
	return if n.kind == "expr" and n.tag == "conditional" then n else nil
end

function utils.isExpr(n: types.AstNode): types.AstExpr?
	return if n.kind == "expr" then n else nil
end

function utils.isStatBlock(n: types.AstNode): types.AstStatBlock?
	return if n.kind == "stat" and n.tag == "block" then n else nil
end

function utils.isStatIf(n: types.AstNode): types.AstStatIf?
	return if n.kind == "stat" and n.tag == "conditional" then n else nil
end

function utils.isStatWhile(n: types.AstNode): types.AstStatWhile?
	return if n.kind == "stat" and n.tag == "while" then n else nil
end

function utils.isStatRepeat(n: types.AstNode): types.AstStatRepeat?
	return if n.kind == "stat" and n.tag == "repeat" then n else nil
end

function utils.isStatBreak(n: types.AstNode): types.AstStatBreak?
	return if n.kind == "stat" and n.tag == "break" then n else nil
end

function utils.isStatContinue(n: types.AstNode): types.AstStatContinue?
	return if n.kind == "stat" and n.tag == "continue" then n else nil
end

function utils.isStatReturn(n: types.AstNode): types.AstStatReturn?
	return if n.kind == "stat" and n.tag == "return" then n else nil
end

function utils.isStatExpr(n: types.AstNode): types.AstStatExpr?
	return if n.kind == "stat" and n.tag == "expression" then n else nil
end

function utils.isStatLocal(n: types.AstNode): types.AstStatLocal?
	return if n.kind == "stat" and n.tag == "local" then n else nil
end

function utils.isStatFor(n: types.AstNode): types.AstStatFor?
	return if n.kind == "stat" and n.tag == "for" then n else nil
end

function utils.isStatForIn(n: types.AstNode): types.AstStatForIn?
	return if n.kind == "stat" and n.tag == "forin" then n else nil
end

function utils.isStatAssign(n: types.AstNode): types.AstStatAssign?
	return if n.kind == "stat" and n.tag == "assign" then n else nil
end

function utils.isStatCompoundAssign(n: types.AstNode): types.AstStatCompoundAssign?
	return if n.kind == "stat" and n.tag == "compoundassign" then n else nil
end

function utils.isStatFunction(n: types.AstNode): types.AstStatFunction?
	return if n.kind == "stat" and n.tag == "function" then n else nil
end

function utils.isStatLocalFunction(n: types.AstNode): types.AstStatLocalFunction?
	return if n.kind == "stat" and n.tag == "localfunction" then n else nil
end

function utils.isStatTypeAlias(n: types.AstNode): types.AstStatTypeAlias?
	return if n.kind == "stat" and n.tag == "typealias" then n else nil
end

function utils.isStatTypeFunction(n: types.AstNode): types.AstStatTypeFunction?
	return if n.kind == "stat" and n.tag == "typefunction" then n else nil
end

function utils.isStat(n: types.AstNode): types.AstStat?
	return if n.kind == "stat" then n else nil
end

function utils.isGenericType(n: types.AstNode): types.AstGenericType?
	return if n.kind == "type" and n.tag == "generic" then n else nil
end

function utils.isGenericTypePack(n: types.AstNode): types.AstGenericTypePack?
	return if n.kind == "typepack" and n.tag == "genericpack" then n else nil
end

function utils.isTypeReference(n: types.AstNode): types.AstTypeReference?
	return if n.kind == "type" and n.tag == "reference" then n else nil
end

function utils.isTypeSingletonBool(n: types.AstNode): types.AstTypeSingletonBool?
	return if n.kind == "type" and n.tag == "boolean" then n else nil
end

function utils.isTypeSingletonString(n: types.AstNode): types.AstTypeSingletonString?
	return if n.kind == "type" and n.tag == "string" then n else nil
end

function utils.isTypeTypeof(n: types.AstNode): types.AstTypeTypeof?
	return if n.kind == "type" and n.tag == "typeof" then n else nil
end

function utils.isTypeGroup(n: types.AstNode): types.AstTypeGroup?
	return if n.kind == "type" and n.tag == "group" then n else nil
end

function utils.isTypeOptional(n: types.AstNode): types.AstTypeOptional?
	return if n.kind == "type" and n.tag == "optional" then n else nil
end

function utils.isTypeUnion(n: types.AstNode): types.AstTypeUnion?
	return if n.kind == "type" and n.tag == "union" then n else nil
end

function utils.isTypeIntersection(n: types.AstNode): types.AstTypeIntersection?
	return if n.kind == "type" and n.tag == "intersection" then n else nil
end

function utils.isTypeArray(n: types.AstNode): types.AstTypeArray?
	return if n.kind == "type" and n.tag == "array" then n else nil
end

function utils.isTypeTable(n: types.AstNode): types.AstTypeTable?
	return if n.kind == "type" and n.tag == "table" then n else nil
end

function utils.isTypeFunction(n: types.AstNode): types.AstTypeFunction?
	return if n.kind == "type" and n.tag == "function" then n else nil
end

function utils.isType(n: types.AstNode): types.AstType?
	return if n.kind == "type" then n else nil
end

function utils.isTypePackExplicit(n: types.AstNode): types.AstTypePackExplicit?
	return if n.kind == "typepack" and n.tag == "explicit" then n else nil
end

function utils.isTypePackVariadic(n: types.AstNode): types.AstTypePackVariadic?
	return if n.kind == "typepack" and n.tag == "variadic" then n else nil
end

function utils.isTypePackGeneric(n: types.AstNode): types.AstTypePackGeneric?
	return if n.kind == "typepack" and n.tag == "generic" then n else nil
end

function utils.isTypePack(n: types.AstNode): types.AstTypePack?
	return if n.kind == "typepack" then n else nil
end

function utils.isToken(n: types.AstNode): types.Token?
	return if n.kind == "token" then n else nil
end

function utils.isAttribute(n: types.AstAttribute): types.AstAttribute?
	return if n.kind == "attribute" then n else nil
end

utils.leftmosttrivia = retriever.leftmosttrivia
utils.rightmosttrivia = retriever.rightmosttrivia

return table.freeze(utils)
