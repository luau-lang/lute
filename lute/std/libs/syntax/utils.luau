local luau = require("@lute/luau")

local utils = {}

function utils.isLocal(n: luau.AstNode): luau.AstLocal?
	return if n.kind == "local" then n else nil
end

function utils.isExprGroup(n: luau.AstNode): luau.AstExprGroup?
	return if n.kind == "expr" and n.tag == "group" then n else nil
end

function utils.isExprConstantNil(n: luau.AstNode): luau.AstExprConstantNil?
	return if n.kind == "expr" and n.tag == "nil" then n else nil
end

function utils.isExprConstantBool(n: luau.AstNode): luau.AstExprConstantBool?
	return if n.kind == "expr" and n.tag == "bool" then n else nil
end

function utils.isExprConstantNumber(n: luau.AstNode): luau.AstExprConstantNumber?
	return if n.kind == "expr" and n.tag == "number" then n else nil
end

function utils.isExprConstantString(n: luau.AstNode): luau.AstExprConstantString?
	return if n.kind == "expr" and n.tag == "string" then n else nil
end

function utils.isExprLocal(n: luau.AstNode): luau.AstExprLocal?
	return if n.kind == "expr" and n.tag == "local" then n else nil
end

function utils.isExprGlobal(n: luau.AstNode): luau.AstExprGlobal?
	return if n.kind == "expr" and n.tag == "global" then n else nil
end

function utils.isExprVarargs(n: luau.AstNode): luau.AstExprVarargs?
	return if n.kind == "expr" and n.tag == "vararg" then n else nil
end

function utils.isExprCall(n: luau.AstNode): luau.AstExprCall?
	return if n.kind == "expr" and n.tag == "call" then n else nil
end

function utils.isExprIndexName(n: luau.AstNode): luau.AstExprIndexName?
	return if n.kind == "expr" and n.tag == "indexname" then n else nil
end

function utils.isExprIndexExpr(n: luau.AstNode): luau.AstExprIndexExpr?
	return if n.kind == "expr" and n.tag == "index" then n else nil
end

function utils.isExprAnonymousFunction(n: luau.AstNode): luau.AstExprAnonymousFunction?
	return if n.kind == "expr" and n.tag == "function" then n else nil
end

function utils.isExprTable(n: luau.AstNode): luau.AstExprTable?
	return if n.kind == "expr" and n.tag == "table" then n else nil
end

function utils.isExprUnary(n: luau.AstNode): luau.AstExprUnary?
	return if n.kind == "expr" and n.tag == "unary" then n else nil
end

function utils.isExprBinary(n: luau.AstNode): luau.AstExprBinary?
	return if n.kind == "expr" and n.tag == "binary" then n else nil
end

function utils.isExprInterpString(n: luau.AstNode): luau.AstExprInterpString?
	return if n.kind == "expr" and n.tag == "interpolatedstring" then n else nil
end

function utils.isExprTypeAssertion(n: luau.AstNode): luau.AstExprTypeAssertion?
	return if n.kind == "expr" and n.tag == "cast" then n else nil
end

function utils.isExprIfElse(n: luau.AstNode): luau.AstExprIfElse?
	return if n.kind == "expr" and n.tag == "conditional" then n else nil
end

function utils.isExpr(n: luau.AstNode): luau.AstExpr?
	return if n.kind == "expr" then n else nil
end

function utils.isStatBlock(n: luau.AstNode): luau.AstStatBlock?
	return if n.kind == "stat" and n.tag == "block" then n else nil
end

function utils.isStatIf(n: luau.AstNode): luau.AstStatIf?
	return if n.kind == "stat" and n.tag == "conditional" then n else nil
end

function utils.isStatWhile(n: luau.AstNode): luau.AstStatWhile?
	return if n.kind == "stat" and n.tag == "while" then n else nil
end

function utils.isStatRepeat(n: luau.AstNode): luau.AstStatRepeat?
	return if n.kind == "stat" and n.tag == "repeat" then n else nil
end

function utils.isStatBreak(n: luau.AstNode): luau.AstStatBreak?
	return if n.kind == "stat" and n.tag == "break" then n else nil
end

function utils.isStatContinue(n: luau.AstNode): luau.AstStatContinue?
	return if n.kind == "stat" and n.tag == "continue" then n else nil
end

function utils.isStatReturn(n: luau.AstNode): luau.AstStatReturn?
	return if n.kind == "stat" and n.tag == "return" then n else nil
end

function utils.isStatExpr(n: luau.AstNode): luau.AstStatExpr?
	return if n.kind == "stat" and n.tag == "expression" then n else nil
end

function utils.isStatLocal(n: luau.AstNode): luau.AstStatLocal?
	return if n.kind == "stat" and n.tag == "local" then n else nil
end

function utils.isStatFor(n: luau.AstNode): luau.AstStatFor?
	return if n.kind == "stat" and n.tag == "for" then n else nil
end

function utils.isStatForIn(n: luau.AstNode): luau.AstStatForIn?
	return if n.kind == "stat" and n.tag == "forin" then n else nil
end

function utils.isStatAssign(n: luau.AstNode): luau.AstStatAssign?
	return if n.kind == "stat" and n.tag == "assign" then n else nil
end

function utils.isStatCompoundAssign(n: luau.AstNode): luau.AstStatCompoundAssign?
	return if n.kind == "stat" and n.tag == "compoundassign" then n else nil
end

function utils.isStatFunction(n: luau.AstNode): luau.AstStatFunction?
	return if n.kind == "stat" and n.tag == "function" then n else nil
end

function utils.isStatLocalFunction(n: luau.AstNode): luau.AstStatLocalFunction?
	return if n.kind == "stat" and n.tag == "localfunction" then n else nil
end

function utils.isStatTypeAlias(n: luau.AstNode): luau.AstStatTypeAlias?
	return if n.kind == "stat" and n.tag == "typealias" then n else nil
end

function utils.isStatTypeFunction(n: luau.AstNode): luau.AstStatTypeFunction?
	return if n.kind == "stat" and n.tag == "typefunction" then n else nil
end

function utils.isStat(n: luau.AstNode): luau.AstStat?
	return if n.kind == "stat" then n else nil
end

function utils.isGenericType(n: luau.AstNode): luau.AstGenericType?
	return if n.kind == "type" and n.tag == "generic" then n else nil
end

function utils.isGenericTypePack(n: luau.AstNode): luau.AstGenericTypePack?
	return if n.kind == "typepack" and n.tag == "genericpack" then n else nil
end

function utils.isTypeReference(n: luau.AstNode): luau.AstTypeReference?
	return if n.kind == "type" and n.tag == "reference" then n else nil
end

function utils.isTypeSingletonBool(n: luau.AstNode): luau.AstTypeSingletonBool?
	return if n.kind == "type" and n.tag == "boolean" then n else nil
end

function utils.isTypeSingletonString(n: luau.AstNode): luau.AstTypeSingletonString?
	return if n.kind == "type" and n.tag == "string" then n else nil
end

function utils.isTypeTypeof(n: luau.AstNode): luau.AstTypeTypeof?
	return if n.kind == "type" and n.tag == "typeof" then n else nil
end

function utils.isTypeGroup(n: luau.AstNode): luau.AstTypeGroup?
	return if n.kind == "type" and n.tag == "group" then n else nil
end

function utils.isTypeOptional(n: luau.AstNode): luau.AstTypeOptional?
	return if n.kind == "type" and n.tag == "optional" then n else nil
end

function utils.isTypeUnion(n: luau.AstNode): luau.AstTypeUnion?
	return if n.kind == "type" and n.tag == "union" then n else nil
end

function utils.isTypeIntersection(n: luau.AstNode): luau.AstTypeIntersection?
	return if n.kind == "type" and n.tag == "intersection" then n else nil
end

function utils.isTypeArray(n: luau.AstNode): luau.AstTypeArray?
	return if n.kind == "type" and n.tag == "array" then n else nil
end

function utils.isTypeTable(n: luau.AstNode): luau.AstTypeTable?
	return if n.kind == "type" and n.tag == "table" then n else nil
end

function utils.isTypeFunction(n: luau.AstNode): luau.AstTypeFunction?
	return if n.kind == "type" and n.tag == "function" then n else nil
end

function utils.isType(n: luau.AstNode): luau.AstType?
	return if n.kind == "type" then n else nil
end

function utils.isTypePackExplicit(n: luau.AstNode): luau.AstTypePackExplicit?
	return if n.kind == "typepack" and n.tag == "explicit" then n else nil
end

function utils.isTypePackVariadic(n: luau.AstNode): luau.AstTypePackVariadic?
	return if n.kind == "typepack" and n.tag == "variadic" then n else nil
end

function utils.isTypePackGeneric(n: luau.AstNode): luau.AstTypePackGeneric?
	return if n.kind == "typepack" and n.tag == "generic" then n else nil
end

function utils.isTypePack(n: luau.AstNode): luau.AstTypePack?
	return if n.kind == "typepack" then n else nil
end

return table.freeze(utils)
