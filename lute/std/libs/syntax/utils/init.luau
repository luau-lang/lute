local types = require("./types")

local utils = {}

--- Returns `n` narrowed to `CstLocal` if it is a local variable node, or `nil` otherwise.
function utils.isLocal(n: types.CstNode): types.CstLocal?
	return if n.kind == "local" then n else nil
end

--- Returns `n` narrowed to `CstExprGroup` if it is a parenthesized expression, or `nil` otherwise.
function utils.isExprGroup(n: types.CstNode): types.CstExprGroup?
	return if n.kind == "expr" and n.tag == "group" then n else nil
end

--- Returns `n` narrowed to `CstExprConstantNil` if it is a nil literal expression, or `nil` otherwise.
function utils.isExprConstantNil(n: types.CstNode): types.CstExprConstantNil?
	return if n.kind == "expr" and n.tag == "nil" then n else nil
end

--- Returns `n` narrowed to `CstExprConstantBool` if it is a boolean literal expression, or `nil` otherwise.
function utils.isExprConstantBool(n: types.CstNode): types.CstExprConstantBool?
	return if n.kind == "expr" and n.tag == "boolean" then n else nil
end

--- Returns `n` narrowed to `CstExprConstantNumber` if it is a number literal expression, or `nil` otherwise.
function utils.isExprConstantNumber(n: types.CstNode): types.CstExprConstantNumber?
	return if n.kind == "expr" and n.tag == "number" then n else nil
end

--- Returns `n` narrowed to `CstExprConstantString` if it is a string literal expression, or `nil` otherwise.
function utils.isExprConstantString(n: types.CstNode): types.CstExprConstantString?
	return if n.kind == "expr" and n.tag == "string" then n else nil
end

--- Returns `n` narrowed to `CstExprLocal` if it is a local variable reference expression, or `nil` otherwise.
function utils.isExprLocal(n: types.CstNode): types.CstExprLocal?
	return if n.kind == "expr" and n.tag == "local" then n else nil
end

--- Returns `n` narrowed to `CstExprGlobal` if it is a global variable reference expression, or `nil` otherwise.
function utils.isExprGlobal(n: types.CstNode): types.CstExprGlobal?
	return if n.kind == "expr" and n.tag == "global" then n else nil
end

--- Returns `n` narrowed to `CstExprVarargs` if it is a varargs expression (`...`), or `nil` otherwise.
function utils.isExprVarargs(n: types.CstNode): types.CstExprVarargs?
	return if n.kind == "expr" and n.tag == "vararg" then n else nil
end

--- Returns `n` narrowed to `CstExprCall` if it is a call expression, or `nil` otherwise.
function utils.isExprCall(n: types.CstNode): types.CstExprCall?
	return if n.kind == "expr" and n.tag == "call" then n else nil
end

--- Returns `n` as an `CstExprCall` if it is a `require(...)` call expression, or `nil` otherwise.
function utils.isRequireCall(n: types.CstNode): types.CstExprCall?
	local call = utils.isExprCall(n)
	local global = call and utils.isExprGlobal(call.func)
	return if global and global.name.text == "require" then call else nil
end

--- Returns `n` narrowed to `CstExprIndexName` if it is a field access expression (e.g. `a.b`), or `nil` otherwise.
function utils.isExprIndexName(n: types.CstNode): types.CstExprIndexName?
	return if n.kind == "expr" and n.tag == "indexname" then n else nil
end

--- Returns `n` narrowed to `CstExprIndexExpr` if it is an index expression (e.g. `a[b]`), or `nil` otherwise.
function utils.isExprIndexExpr(n: types.CstNode): types.CstExprIndexExpr?
	return if n.kind == "expr" and n.tag == "index" then n else nil
end

--- Returns `n` narrowed to `CstExprFunction` if it is a function expression, or `nil` otherwise.
function utils.isExprFunction(n: types.CstNode): types.CstExprFunction?
	return if n.kind == "expr" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `CstExprTable` if it is a table constructor expression, or `nil` otherwise.
function utils.isExprTable(n: types.CstNode): types.CstExprTable?
	return if n.kind == "expr" and n.tag == "table" then n else nil
end

--- Returns `n` narrowed to `CstTableExprItem` if it is a table constructor item, or `nil` otherwise.
function utils.isTableExprItem(n: types.CstNode | types.CstTableExprItem): types.CstTableExprItem?
	return if (n :: types.CstTableExprItem).isTableItem then n :: types.CstTableExprItem else nil
end

--- Returns `n` narrowed to `CstExprUnary` if it is a unary expression, or `nil` otherwise.
function utils.isExprUnary(n: types.CstNode): types.CstExprUnary?
	return if n.kind == "expr" and n.tag == "unary" then n else nil
end

--- Returns `n` narrowed to `CstExprBinary` if it is a binary expression, or `nil` otherwise.
function utils.isExprBinary(n: types.CstNode): types.CstExprBinary?
	return if n.kind == "expr" and n.tag == "binary" then n else nil
end

--- Returns `n` narrowed to `CstExprInterpString` if it is an interpolated string expression, or `nil` otherwise.
function utils.isExprInterpString(n: types.CstNode): types.CstExprInterpString?
	return if n.kind == "expr" and n.tag == "interpolatedstring" then n else nil
end

--- Returns `n` narrowed to `CstExprTypeAssertion` if it is a type assertion expression (`expr :: Type`), or `nil` otherwise.
function utils.isExprTypeAssertion(n: types.CstNode): types.CstExprTypeAssertion?
	return if n.kind == "expr" and n.tag == "cast" then n else nil
end

--- Returns `n` narrowed to `CstExprIfElse` if it is an `if-then-else` expression, or `nil` otherwise.
function utils.isExprIfElse(n: types.CstNode): types.CstExprIfElse?
	return if n.kind == "expr" and n.tag == "conditional" then n else nil
end

--- Returns `n` narrowed to `CstExpr` if it is any expression node, or `nil` otherwise.
function utils.isExpr(n: types.CstNode): types.CstExpr?
	return if n.kind == "expr" then n else nil
end

--- Returns `n` narrowed to `CstStatBlock` if it is a block statement (do...end), or `nil` otherwise.
function utils.isStatBlock(n: types.CstNode): types.CstStatBlock?
	return if n.kind == "stat" and n.tag == "block" then n else nil
end

--- Returns `n` narrowed to `CstStatIf` if it is an if statement, or `nil` otherwise.
function utils.isStatIf(n: types.CstNode): types.CstStatIf?
	return if n.kind == "stat" and n.tag == "conditional" then n else nil
end

--- Returns `n` narrowed to `CstStatWhile` if it is a while statement, or `nil` otherwise.
function utils.isStatWhile(n: types.CstNode): types.CstStatWhile?
	return if n.kind == "stat" and n.tag == "while" then n else nil
end

--- Returns `n` narrowed to `CstStatRepeat` if it is a repeat-until statement, or `nil` otherwise.
function utils.isStatRepeat(n: types.CstNode): types.CstStatRepeat?
	return if n.kind == "stat" and n.tag == "repeat" then n else nil
end

--- Returns `n` narrowed to `CstStatBreak` if it is a break statement, or `nil` otherwise.
function utils.isStatBreak(n: types.CstNode): types.CstStatBreak?
	return if n.kind == "stat" and n.tag == "break" then n else nil
end

--- Returns `n` narrowed to `CstStatContinue` if it is a continue statement, or `nil` otherwise.
function utils.isStatContinue(n: types.CstNode): types.CstStatContinue?
	return if n.kind == "stat" and n.tag == "continue" then n else nil
end

--- Returns `n` narrowed to `CstStatReturn` if it is a return statement, or `nil` otherwise.
function utils.isStatReturn(n: types.CstNode): types.CstStatReturn?
	return if n.kind == "stat" and n.tag == "return" then n else nil
end

--- Returns `n` narrowed to `CstStatExpr` if it is an expression statement, or `nil` otherwise.
function utils.isStatExpr(n: types.CstNode): types.CstStatExpr?
	return if n.kind == "stat" and n.tag == "expression" then n else nil
end

--- Returns `n` narrowed to `CstStatLocal` if it is a local variable declaration, or `nil` otherwise.
function utils.isStatLocal(n: types.CstNode): types.CstStatLocal?
	return if n.kind == "stat" and n.tag == "local" then n else nil
end

--- Returns `n` narrowed to `CstStatConst` if it is a const variable declaration, or `nil` otherwise.
function utils.isStatConst(n: types.CstNode): types.CstStatConst?
	return if n.kind == "stat" and n.tag == "const" then n else nil
end

--- Returns `n` narrowed to `CstStatFor` if it is a numeric for statement, or `nil` otherwise.
function utils.isStatFor(n: types.CstNode): types.CstStatFor?
	return if n.kind == "stat" and n.tag == "for" then n else nil
end

--- Returns `n` narrowed to `CstStatForIn` if it is a generic for-in statement, or `nil` otherwise.
function utils.isStatForIn(n: types.CstNode): types.CstStatForIn?
	return if n.kind == "stat" and n.tag == "forin" then n else nil
end

--- Returns `n` narrowed to `CstStatAssign` if it is an assignment statement, or `nil` otherwise.
function utils.isStatAssign(n: types.CstNode): types.CstStatAssign?
	return if n.kind == "stat" and n.tag == "assign" then n else nil
end

--- Returns `n` narrowed to `CstStatCompoundAssign` if it is a compound assignment statement (e.g. `+=`), or `nil` otherwise.
function utils.isStatCompoundAssign(n: types.CstNode): types.CstStatCompoundAssign?
	return if n.kind == "stat" and n.tag == "compoundassign" then n else nil
end

--- Returns `n` narrowed to `CstStatFunction` if it is a function declaration statement, or `nil` otherwise.
function utils.isStatFunction(n: types.CstNode): types.CstStatFunction?
	return if n.kind == "stat" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `CstStatLocalFunction` if it is a local function declaration, or `nil` otherwise.
function utils.isStatLocalFunction(n: types.CstNode): types.CstStatLocalFunction?
	return if n.kind == "stat" and n.tag == "localfunction" then n else nil
end

--- Returns `n` narrowed to `CstStatTypeAlias` if it is a type alias declaration, or `nil` otherwise.
function utils.isStatTypeAlias(n: types.CstNode): types.CstStatTypeAlias?
	return if n.kind == "stat" and n.tag == "typealias" then n else nil
end

--- Returns `n` narrowed to `CstStatTypeFunction` if it is a type function declaration, or `nil` otherwise.
function utils.isStatTypeFunction(n: types.CstNode): types.CstStatTypeFunction?
	return if n.kind == "stat" and n.tag == "typefunction" then n else nil
end

--- Returns `n` narrowed to `CstStat` if it is any statement node, or `nil` otherwise.
function utils.isStat(n: types.CstNode): types.CstStat?
	return if n.kind == "stat" then n else nil
end

--- Returns `n` narrowed to `CstGenericType` if it is a generic type parameter, or `nil` otherwise.
function utils.isGenericType(n: types.CstNode): types.CstGenericType?
	return if n.kind == "type" and n.tag == "generic" then n else nil
end

--- Returns `n` narrowed to `CstGenericTypePack` if it is a generic type pack parameter, or `nil` otherwise.
function utils.isGenericTypePack(n: types.CstNode): types.CstGenericTypePack?
	return if n.kind == "typepack" and n.tag == "genericpack" then n else nil
end

--- Returns `n` narrowed to `CstTypeReference` if it is a type reference, or `nil` otherwise.
function utils.isTypeReference(n: types.CstNode): types.CstTypeReference?
	return if n.kind == "type" and n.tag == "reference" then n else nil
end

--- Returns `n` narrowed to `CstTypeSingletonBool` if it is a boolean singleton type, or `nil` otherwise.
function utils.isTypeSingletonBool(n: types.CstNode): types.CstTypeSingletonBool?
	return if n.kind == "type" and n.tag == "boolean" then n else nil
end

--- Returns `n` narrowed to `CstTypeSingletonString` if it is a string singleton type, or `nil` otherwise.
function utils.isTypeSingletonString(n: types.CstNode): types.CstTypeSingletonString?
	return if n.kind == "type" and n.tag == "string" then n else nil
end

--- Returns `n` narrowed to `CstTypeTypeof` if it is a `typeof(...)` type, or `nil` otherwise.
function utils.isTypeTypeof(n: types.CstNode): types.CstTypeTypeof?
	return if n.kind == "type" and n.tag == "typeof" then n else nil
end

--- Returns `n` narrowed to `CstTypeGroup` if it is a parenthesized type, or `nil` otherwise.
function utils.isTypeGroup(n: types.CstNode): types.CstTypeGroup?
	return if n.kind == "type" and n.tag == "group" then n else nil
end

--- Returns `n` narrowed to `CstTypeOptional` if it is an optional type (`T?`), or `nil` otherwise.
function utils.isTypeOptional(n: types.CstNode): types.CstTypeOptional?
	return if n.kind == "type" and n.tag == "optional" then n else nil
end

--- Returns `n` narrowed to `CstTypeUnion` if it is a type union, or `nil` otherwise.
function utils.isTypeUnion(n: types.CstNode): types.CstTypeUnion?
	return if n.kind == "type" and n.tag == "union" then n else nil
end

--- Returns `n` narrowed to `CstTypeIntersection` if it is a type intersection, or `nil` otherwise.
function utils.isTypeIntersection(n: types.CstNode): types.CstTypeIntersection?
	return if n.kind == "type" and n.tag == "intersection" then n else nil
end

--- Returns `n` narrowed to `CstTypeArray` if it is an array type (`{T}`), or `nil` otherwise.
function utils.isTypeArray(n: types.CstNode): types.CstTypeArray?
	return if n.kind == "type" and n.tag == "array" then n else nil
end

--- Returns `n` narrowed to `CstTypeTable` if it is a table type, or `nil` otherwise.
function utils.isTypeTable(n: types.CstNode): types.CstTypeTable?
	return if n.kind == "type" and n.tag == "table" then n else nil
end

--- Returns `n` narrowed to `CstTypeFunction` if it is a function type, or `nil` otherwise.
function utils.isTypeFunction(n: types.CstNode): types.CstTypeFunction?
	return if n.kind == "type" and n.tag == "function" then n else nil
end

--- Returns `n` narrowed to `CstType` if it is any type annotation node, or `nil` otherwise.
function utils.isType(n: types.CstNode): types.CstType?
	return if n.kind == "type" then n else nil
end

--- Returns `n` narrowed to `CstTypePackExplicit` if it is an explicit type pack, or `nil` otherwise.
function utils.isTypePackExplicit(n: types.CstNode): types.CstTypePackExplicit?
	return if n.kind == "typepack" and n.tag == "explicit" then n else nil
end

--- Returns `n` narrowed to `CstTypePackVariadic` if it is a variadic type pack, or `nil` otherwise.
function utils.isTypePackVariadic(n: types.CstNode): types.CstTypePackVariadic?
	return if n.kind == "typepack" and n.tag == "variadic" then n else nil
end

--- Returns `n` narrowed to `CstTypePackGeneric` if it is a generic type pack, or `nil` otherwise.
function utils.isTypePackGeneric(n: types.CstNode): types.CstTypePackGeneric?
	return if n.kind == "typepack" and n.tag == "generic" then n else nil
end

--- Returns `n` narrowed to `CstTypePack` if it is any type pack node, or `nil` otherwise.
function utils.isTypePack(n: types.CstNode): types.CstTypePack?
	return if n.kind == "typepack" then n else nil
end

--- Returns `n` narrowed to `CstToken` if it is a token, or `nil` otherwise.
function utils.isToken(n: types.CstNode): types.CstToken?
	return if n.kind == "token" then n else nil
end

--- Returns `n` narrowed to `CstAttribute` if it is an attribute node, or `nil` otherwise.
function utils.isAttribute(n: types.CstNode): types.CstAttribute?
	return if n.kind == "attribute" then n else nil
end

--- Returns `n` narrowed to `CstAttributeSimple` if it is a simple attribute node, or `nil` otherwise.
function utils.isAttributeSimple(n: types.CstNode): types.CstAttributeSimple?
	return if n.kind == "attribute" and n.tag == "simple" then n else nil
end

--- Returns `n` narrowed to `CstAttributeParametrized` if it is a parametrized attribute node, or `nil` otherwise.
function utils.isAttributeParametrized(n: types.CstNode): types.CstAttributeParametrized?
	return if n.kind == "attribute" and n.tag == "parametrized" then n else nil
end

--- Returns `n` narrowed to `CstAttributeList` if it is an attribute list node, or `nil` otherwise.
function utils.isAttributeList(n: types.CstNode): types.CstAttributeList?
	return if n.kind == "attribute" and n.tag == "list" then n else nil
end

--- Returns a `Replacement` that replaces the original node with the given content, preserving trivia.
function utils.replacementWithTrivia(content: string): types.Replacement
	return { content = content }
end

--- Returns a `Replacement` that replaces the original node with the given content, discarding trivia.
function utils.replacementWithoutTrivia(content: string): types.Replacement
	return { content = content, preserveTrivia = false }
end

return table.freeze(utils)
