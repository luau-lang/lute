local types = require("./types")

local utils = {}

--- Returns `n` narrowed to `AstLocal` if it is a local variable node, or `nil` otherwise.
function utils.isLocal(n: types.AstNode): types.AstLocal?
	return if n.kind == "local" then n else nil
end

--- Returns `n` narrowed to `AstExprGroup` if it is a parenthesized expression, or `nil` otherwise.
function utils.isExprGroup(n: types.AstNode): types.AstExprGroup?
	return if n.kind == "expr" and n.tag == "group" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantNil` if it is a nil literal expression, or `nil` otherwise.
function utils.isExprConstantNil(n: types.AstNode): types.AstExprConstantNil?
	return if n.kind == "expr" and n.tag == "nil" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantBool` if it is a boolean literal expression, or `nil` otherwise.
function utils.isExprConstantBool(n: types.AstNode): types.AstExprConstantBool?
	return if n.kind == "expr" and n.tag == "boolean" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantNumber` if it is a number literal expression, or `nil` otherwise.
function utils.isExprConstantNumber(n: types.AstNode): types.AstExprConstantNumber?
	return if n.kind == "expr" and n.tag == "number" then n else nil
end

--- Returns `n` narrowed to `AstExprConstantString` if it is a string literal expression, or `nil` otherwise.
function utils.isExprConstantString(n: types.AstNode): types.AstExprConstantString?
	return if n.kind == "expr" and n.tag == "string" then n else nil
end

--- Returns `n` narrowed to `AstExprLocal` if it is a local variable reference expression, or `nil` otherwise.
function utils.isExprLocal(n: types.AstNode): types.AstExprLocal?
	return if n.kind == "expr" and n.tag == "local" then n else nil
end

--- Returns `n` narrowed to `AstExprGlobal` if it is a global variable reference expression, or `nil` otherwise.
function utils.isExprGlobal(n: types.AstNode): types.AstExprGlobal?
	return if n.kind == "expr" and n.tag == "global" then n else nil
end

--- Returns `n` narrowed to `AstExprVarargs` if it is a varargs expression (`...`), or `nil` otherwise.
function utils.isExprVarargs(n: types.AstNode): types.AstExprVarargs?
	return if n.kind == "expr" and n.tag == "vararg" then n else nil
end

--- Returns `n` narrowed to `AstExprCall` if it is a call expression, or `nil` otherwise.
function utils.isExprCall(n: types.AstNode): types.AstExprCall?
	return if n.kind == "expr" and n.tag == "call" then n else nil
end

--- Returns `n` as an `AstExprCall` if it is a `require(...)` call expression, or `nil` otherwise.
function utils.isRequireCall(n: types.AstNode): types.AstExprCall?
	local call = utils.isExprCall(n)
	local global = call and utils.isExprGlobal(call.func)
	return if global and global.name.text == "require" then call else nil
end

--- Returns `n` narrowed to `AstExprIndexName` if it is a field access expression (e.g. `a.b`), or `nil` otherwise.
function utils.isExprIndexName(n: types.AstNode): types.AstExprIndexName?
	return if n.kind == "expr" and n.tag == "indexname" then n else nil
end

--- Returns `n` narrowed to `AstExprIndexExpr` if it is an index expression (e.g. `a[b]`), or `nil` otherwise.
function utils.isExprIndexExpr(n: types.AstNode): types.AstExprIndexExpr?
	return if n.kind == "expr" and n.tag == "index" then n else nil
end

--- Returns `n` narrowed to `AstExprFunction` if it is a function expression, or `nil` otherwise.
function utils.isExprFunction(n: types.AstNode): types.AstExprFunction?
	return if n.kind == "expr" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `AstExprTable` if it is a table constructor expression, or `nil` otherwise.
function utils.isExprTable(n: types.AstNode): types.AstExprTable?
	return if n.kind == "expr" and n.tag == "table" then n else nil
end

--- Returns `n` narrowed to `AstTableExprItem` if it is a table constructor item, or `nil` otherwise.
function utils.isTableExprItem(n: types.AstNode | types.AstTableExprItem): types.AstTableExprItem?
	return if (n :: types.AstTableExprItem).isTableItem then n :: types.AstTableExprItem else nil
end

--- Returns `n` narrowed to `AstExprUnary` if it is a unary expression, or `nil` otherwise.
function utils.isExprUnary(n: types.AstNode): types.AstExprUnary?
	return if n.kind == "expr" and n.tag == "unary" then n else nil
end

--- Returns `n` narrowed to `AstExprBinary` if it is a binary expression, or `nil` otherwise.
function utils.isExprBinary(n: types.AstNode): types.AstExprBinary?
	return if n.kind == "expr" and n.tag == "binary" then n else nil
end

--- Returns `n` narrowed to `AstExprInterpString` if it is an interpolated string expression, or `nil` otherwise.
function utils.isExprInterpString(n: types.AstNode): types.AstExprInterpString?
	return if n.kind == "expr" and n.tag == "interpolatedstring" then n else nil
end

--- Returns `n` narrowed to `AstExprTypeAssertion` if it is a type assertion expression (`expr :: Type`), or `nil` otherwise.
function utils.isExprTypeAssertion(n: types.AstNode): types.AstExprTypeAssertion?
	return if n.kind == "expr" and n.tag == "cast" then n else nil
end

--- Returns `n` narrowed to `AstExprIfElse` if it is an `if-then-else` expression, or `nil` otherwise.
function utils.isExprIfElse(n: types.AstNode): types.AstExprIfElse?
	return if n.kind == "expr" and n.tag == "conditional" then n else nil
end

--- Returns `n` narrowed to `AstExpr` if it is any expression node, or `nil` otherwise.
function utils.isExpr(n: types.AstNode): types.AstExpr?
	return if n.kind == "expr" then n else nil
end

--- Returns `n` narrowed to `AstStatBlock` if it is a block statement (do...end), or `nil` otherwise.
function utils.isStatBlock(n: types.AstNode): types.AstStatBlock?
	return if n.kind == "stat" and n.tag == "block" then n else nil
end

--- Returns `n` narrowed to `AstStatIf` if it is an if statement, or `nil` otherwise.
function utils.isStatIf(n: types.AstNode): types.AstStatIf?
	return if n.kind == "stat" and n.tag == "conditional" then n else nil
end

--- Returns `n` narrowed to `AstStatWhile` if it is a while statement, or `nil` otherwise.
function utils.isStatWhile(n: types.AstNode): types.AstStatWhile?
	return if n.kind == "stat" and n.tag == "while" then n else nil
end

--- Returns `n` narrowed to `AstStatRepeat` if it is a repeat-until statement, or `nil` otherwise.
function utils.isStatRepeat(n: types.AstNode): types.AstStatRepeat?
	return if n.kind == "stat" and n.tag == "repeat" then n else nil
end

--- Returns `n` narrowed to `AstStatBreak` if it is a break statement, or `nil` otherwise.
function utils.isStatBreak(n: types.AstNode): types.AstStatBreak?
	return if n.kind == "stat" and n.tag == "break" then n else nil
end

--- Returns `n` narrowed to `AstStatContinue` if it is a continue statement, or `nil` otherwise.
function utils.isStatContinue(n: types.AstNode): types.AstStatContinue?
	return if n.kind == "stat" and n.tag == "continue" then n else nil
end

--- Returns `n` narrowed to `AstStatReturn` if it is a return statement, or `nil` otherwise.
function utils.isStatReturn(n: types.AstNode): types.AstStatReturn?
	return if n.kind == "stat" and n.tag == "return" then n else nil
end

--- Returns `n` narrowed to `AstStatExpr` if it is an expression statement, or `nil` otherwise.
function utils.isStatExpr(n: types.AstNode): types.AstStatExpr?
	return if n.kind == "stat" and n.tag == "expression" then n else nil
end

--- Returns `n` narrowed to `AstStatLocal` if it is a local variable declaration, or `nil` otherwise.
function utils.isStatLocal(n: types.AstNode): types.AstStatLocal?
	return if n.kind == "stat" and n.tag == "local" then n else nil
end

--- Returns `n` narrowed to `AstStatFor` if it is a numeric for statement, or `nil` otherwise.
function utils.isStatFor(n: types.AstNode): types.AstStatFor?
	return if n.kind == "stat" and n.tag == "for" then n else nil
end

--- Returns `n` narrowed to `AstStatForIn` if it is a generic for-in statement, or `nil` otherwise.
function utils.isStatForIn(n: types.AstNode): types.AstStatForIn?
	return if n.kind == "stat" and n.tag == "forin" then n else nil
end

--- Returns `n` narrowed to `AstStatAssign` if it is an assignment statement, or `nil` otherwise.
function utils.isStatAssign(n: types.AstNode): types.AstStatAssign?
	return if n.kind == "stat" and n.tag == "assign" then n else nil
end

--- Returns `n` narrowed to `AstStatCompoundAssign` if it is a compound assignment statement (e.g. `+=`), or `nil` otherwise.
function utils.isStatCompoundAssign(n: types.AstNode): types.AstStatCompoundAssign?
	return if n.kind == "stat" and n.tag == "compoundassign" then n else nil
end

--- Returns `n` narrowed to `AstStatFunction` if it is a function declaration statement, or `nil` otherwise.
function utils.isStatFunction(n: types.AstNode): types.AstStatFunction?
	return if n.kind == "stat" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `AstStatLocalFunction` if it is a local function declaration, or `nil` otherwise.
function utils.isStatLocalFunction(n: types.AstNode): types.AstStatLocalFunction?
	return if n.kind == "stat" and n.tag == "localfunction" then n else nil
end

--- Returns `n` narrowed to `AstStatTypeAlias` if it is a type alias declaration, or `nil` otherwise.
function utils.isStatTypeAlias(n: types.AstNode): types.AstStatTypeAlias?
	return if n.kind == "stat" and n.tag == "typealias" then n else nil
end

--- Returns `n` narrowed to `AstStatTypeFunction` if it is a type function declaration, or `nil` otherwise.
function utils.isStatTypeFunction(n: types.AstNode): types.AstStatTypeFunction?
	return if n.kind == "stat" and n.tag == "typefunction" then n else nil
end

--- Returns `n` narrowed to `AstStat` if it is any statement node, or `nil` otherwise.
function utils.isStat(n: types.AstNode): types.AstStat?
	return if n.kind == "stat" then n else nil
end

--- Returns `n` narrowed to `AstGenericType` if it is a generic type parameter, or `nil` otherwise.
function utils.isGenericType(n: types.AstNode): types.AstGenericType?
	return if n.kind == "type" and n.tag == "generic" then n else nil
end

--- Returns `n` narrowed to `AstGenericTypePack` if it is a generic type pack parameter, or `nil` otherwise.
function utils.isGenericTypePack(n: types.AstNode): types.AstGenericTypePack?
	return if n.kind == "typepack" and n.tag == "genericpack" then n else nil
end

--- Returns `n` narrowed to `AstTypeReference` if it is a type reference, or `nil` otherwise.
function utils.isTypeReference(n: types.AstNode): types.AstTypeReference?
	return if n.kind == "type" and n.tag == "reference" then n else nil
end

--- Returns `n` narrowed to `AstTypeSingletonBool` if it is a boolean singleton type, or `nil` otherwise.
function utils.isTypeSingletonBool(n: types.AstNode): types.AstTypeSingletonBool?
	return if n.kind == "type" and n.tag == "boolean" then n else nil
end

--- Returns `n` narrowed to `AstTypeSingletonString` if it is a string singleton type, or `nil` otherwise.
function utils.isTypeSingletonString(n: types.AstNode): types.AstTypeSingletonString?
	return if n.kind == "type" and n.tag == "string" then n else nil
end

--- Returns `n` narrowed to `AstTypeTypeof` if it is a `typeof(...)` type, or `nil` otherwise.
function utils.isTypeTypeof(n: types.AstNode): types.AstTypeTypeof?
	return if n.kind == "type" and n.tag == "typeof" then n else nil
end

--- Returns `n` narrowed to `AstTypeGroup` if it is a parenthesized type, or `nil` otherwise.
function utils.isTypeGroup(n: types.AstNode): types.AstTypeGroup?
	return if n.kind == "type" and n.tag == "group" then n else nil
end

--- Returns `n` narrowed to `AstTypeOptional` if it is an optional type (`T?`), or `nil` otherwise.
function utils.isTypeOptional(n: types.AstNode): types.AstTypeOptional?
	return if n.kind == "type" and n.tag == "optional" then n else nil
end

--- Returns `n` narrowed to `AstTypeUnion` if it is a type union, or `nil` otherwise.
function utils.isTypeUnion(n: types.AstNode): types.AstTypeUnion?
	return if n.kind == "type" and n.tag == "union" then n else nil
end

--- Returns `n` narrowed to `AstTypeIntersection` if it is a type intersection, or `nil` otherwise.
function utils.isTypeIntersection(n: types.AstNode): types.AstTypeIntersection?
	return if n.kind == "type" and n.tag == "intersection" then n else nil
end

--- Returns `n` narrowed to `AstTypeArray` if it is an array type (`{T}`), or `nil` otherwise.
function utils.isTypeArray(n: types.AstNode): types.AstTypeArray?
	return if n.kind == "type" and n.tag == "array" then n else nil
end

--- Returns `n` narrowed to `AstTypeTable` if it is a table type, or `nil` otherwise.
function utils.isTypeTable(n: types.AstNode): types.AstTypeTable?
	return if n.kind == "type" and n.tag == "table" then n else nil
end

--- Returns `n` narrowed to `AstTypeFunction` if it is a function type, or `nil` otherwise.
function utils.isTypeFunction(n: types.AstNode): types.AstTypeFunction?
	return if n.kind == "type" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `AstType` if it is any type annotation node, or `nil` otherwise.
function utils.isType(n: types.AstNode): types.AstType?
	return if n.kind == "type" then n else nil
end

--- Returns `n` narrowed to `AstTypePackExplicit` if it is an explicit type pack, or `nil` otherwise.
function utils.isTypePackExplicit(n: types.AstNode): types.AstTypePackExplicit?
	return if n.kind == "typepack" and n.tag == "explicit" then n else nil
end

--- Returns `n` narrowed to `AstTypePackVariadic` if it is a variadic type pack, or `nil` otherwise.
function utils.isTypePackVariadic(n: types.AstNode): types.AstTypePackVariadic?
	return if n.kind == "typepack" and n.tag == "variadic" then n else nil
end

--- Returns `n` narrowed to `AstTypePackGeneric` if it is a generic type pack, or `nil` otherwise.
function utils.isTypePackGeneric(n: types.AstNode): types.AstTypePackGeneric?
	return if n.kind == "typepack" and n.tag == "generic" then n else nil
end

--- Returns `n` narrowed to `AstTypePack` if it is any type pack node, or `nil` otherwise.
function utils.isTypePack(n: types.AstNode): types.AstTypePack?
	return if n.kind == "typepack" then n else nil
end

--- Returns `n` narrowed to `Token` if it is a token, or `nil` otherwise.
function utils.isToken(n: types.AstNode): types.Token?
	return if n.kind == "token" then n else nil
end

--- Returns `n` narrowed to `AstAttribute` if it is an attribute node, or `nil` otherwise.
function utils.isAttribute(n: types.AstNode): types.AstAttribute?
	return if n.kind == "attribute" then n else nil
end

return table.freeze(utils)
