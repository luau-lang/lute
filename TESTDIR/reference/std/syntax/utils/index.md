# utils

```luau
local utils = require("@std/syntax/utils")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [isAttribute](#utilsisattribute) | Returns `n` narrowed to `AstAttribute` if it is an attribute node, or `nil` otherwise. |
| [isExpr](#utilsisexpr) | Returns `n` narrowed to `AstExpr` if it is any expression node, or `nil` otherwise. |
| [isExprBinary](#utilsisexprbinary) | Returns `n` narrowed to `AstExprBinary` if it is a binary expression, or `nil` otherwise. |
| [isExprCall](#utilsisexprcall) | Returns `n` narrowed to `AstExprCall` if it is a call expression, or `nil` otherwise. |
| [isExprConstantBool](#utilsisexprconstantbool) | Returns `n` narrowed to `AstExprConstantBool` if it is a boolean literal expression, or `nil` otherwise. |
| [isExprConstantNil](#utilsisexprconstantnil) | Returns `n` narrowed to `AstExprConstantNil` if it is a nil literal expression, or `nil` otherwise. |
| [isExprConstantNumber](#utilsisexprconstantnumber) | Returns `n` narrowed to `AstExprConstantNumber` if it is a number literal expression, or `nil` otherwise. |
| [isExprConstantString](#utilsisexprconstantstring) | Returns `n` narrowed to `AstExprConstantString` if it is a string literal expression, or `nil` otherwise. |
| [isExprFunction](#utilsisexprfunction) | Returns `n` narrowed to `AstExprFunction` if it is a function expression, or `nil` otherwise. |
| [isExprGlobal](#utilsisexprglobal) | Returns `n` narrowed to `AstExprGlobal` if it is a global variable reference expression, or `nil` otherwise. |
| [isExprGroup](#utilsisexprgroup) | Returns `n` narrowed to `AstExprGroup` if it is a parenthesized expression, or `nil` otherwise. |
| [isExprIfElse](#utilsisexprifelse) | Returns `n` narrowed to `AstExprIfElse` if it is an `if-then-else` expression, or `nil` otherwise. |
| [isExprIndexExpr](#utilsisexprindexexpr) | Returns `n` narrowed to `AstExprIndexExpr` if it is an index expression (e.g. `a[b]`), or `nil` otherwise. |
| [isExprIndexName](#utilsisexprindexname) | Returns `n` narrowed to `AstExprIndexName` if it is a field access expression (e.g. `a.b`), or `nil` otherwise. |
| [isExprInterpString](#utilsisexprinterpstring) | Returns `n` narrowed to `AstExprInterpString` if it is an interpolated string expression, or `nil` otherwise. |
| [isExprLocal](#utilsisexprlocal) | Returns `n` narrowed to `AstExprLocal` if it is a local variable reference expression, or `nil` otherwise. |
| [isExprTable](#utilsisexprtable) | Returns `n` narrowed to `AstExprTable` if it is a table constructor expression, or `nil` otherwise. |
| [isExprTypeAssertion](#utilsisexprtypeassertion) | Returns `n` narrowed to `AstExprTypeAssertion` if it is a type assertion expression (`expr :: Type`), or `nil` otherwise. |
| [isExprUnary](#utilsisexprunary) | Returns `n` narrowed to `AstExprUnary` if it is a unary expression, or `nil` otherwise. |
| [isExprVarargs](#utilsisexprvarargs) | Returns `n` narrowed to `AstExprVarargs` if it is a varargs expression (`...`), or `nil` otherwise. |
| [isGenericType](#utilsisgenerictype) | Returns `n` narrowed to `AstGenericType` if it is a generic type parameter, or `nil` otherwise. |
| [isGenericTypePack](#utilsisgenerictypepack) | Returns `n` narrowed to `AstGenericTypePack` if it is a generic type pack parameter, or `nil` otherwise. |
| [isLocal](#utilsislocal) | Returns `n` narrowed to `AstLocal` if it is a local variable node, or `nil` otherwise. |
| [isRequireCall](#utilsisrequirecall) | Returns `n` as an `AstExprCall` if it is a `require(...)` call expression, or `nil` otherwise. |
| [isStat](#utilsisstat) | Returns `n` narrowed to `AstStat` if it is any statement node, or `nil` otherwise. |
| [isStatAssign](#utilsisstatassign) | Returns `n` narrowed to `AstStatAssign` if it is an assignment statement, or `nil` otherwise. |
| [isStatBlock](#utilsisstatblock) | Returns `n` narrowed to `AstStatBlock` if it is a block statement (do...end), or `nil` otherwise. |
| [isStatBreak](#utilsisstatbreak) | Returns `n` narrowed to `AstStatBreak` if it is a break statement, or `nil` otherwise. |
| [isStatCompoundAssign](#utilsisstatcompoundassign) | Returns `n` narrowed to `AstStatCompoundAssign` if it is a compound assignment statement (e.g. `+=`), or `nil` otherwise. |
| [isStatContinue](#utilsisstatcontinue) | Returns `n` narrowed to `AstStatContinue` if it is a continue statement, or `nil` otherwise. |
| [isStatExpr](#utilsisstatexpr) | Returns `n` narrowed to `AstStatExpr` if it is an expression statement, or `nil` otherwise. |
| [isStatFor](#utilsisstatfor) | Returns `n` narrowed to `AstStatFor` if it is a numeric for statement, or `nil` otherwise. |
| [isStatForIn](#utilsisstatforin) | Returns `n` narrowed to `AstStatForIn` if it is a generic for-in statement, or `nil` otherwise. |
| [isStatFunction](#utilsisstatfunction) | Returns `n` narrowed to `AstStatFunction` if it is a function declaration statement, or `nil` otherwise. |
| [isStatIf](#utilsisstatif) | Returns `n` narrowed to `AstStatIf` if it is an if statement, or `nil` otherwise. |
| [isStatLocal](#utilsisstatlocal) | Returns `n` narrowed to `AstStatLocal` if it is a local variable declaration, or `nil` otherwise. |
| [isStatLocalFunction](#utilsisstatlocalfunction) | Returns `n` narrowed to `AstStatLocalFunction` if it is a local function declaration, or `nil` otherwise. |
| [isStatRepeat](#utilsisstatrepeat) | Returns `n` narrowed to `AstStatRepeat` if it is a repeat-until statement, or `nil` otherwise. |
| [isStatReturn](#utilsisstatreturn) | Returns `n` narrowed to `AstStatReturn` if it is a return statement, or `nil` otherwise. |
| [isStatTypeAlias](#utilsisstattypealias) | Returns `n` narrowed to `AstStatTypeAlias` if it is a type alias declaration, or `nil` otherwise. |
| [isStatTypeFunction](#utilsisstattypefunction) | Returns `n` narrowed to `AstStatTypeFunction` if it is a type function declaration, or `nil` otherwise. |
| [isStatWhile](#utilsisstatwhile) | Returns `n` narrowed to `AstStatWhile` if it is a while statement, or `nil` otherwise. |
| [isTableExprItem](#utilsistableexpritem) | Returns `n` narrowed to `AstTableExprItem` if it is a table constructor item, or `nil` otherwise. |
| [isToken](#utilsistoken) | Returns `n` narrowed to `Token` if it is a token, or `nil` otherwise. |
| [isType](#utilsistype) | Returns `n` narrowed to `AstType` if it is any type annotation node, or `nil` otherwise. |
| [isTypeArray](#utilsistypearray) | Returns `n` narrowed to `AstTypeArray` if it is an array type (`{T}`), or `nil` otherwise. |
| [isTypeFunction](#utilsistypefunction) | Returns `n` narrowed to `AstTypeFunction` if it is a function type, or `nil` otherwise. |
| [isTypeGroup](#utilsistypegroup) | Returns `n` narrowed to `AstTypeGroup` if it is a parenthesized type, or `nil` otherwise. |
| [isTypeIntersection](#utilsistypeintersection) | Returns `n` narrowed to `AstTypeIntersection` if it is a type intersection, or `nil` otherwise. |
| [isTypeOptional](#utilsistypeoptional) | Returns `n` narrowed to `AstTypeOptional` if it is an optional type (`T?`), or `nil` otherwise. |
| [isTypePack](#utilsistypepack) | Returns `n` narrowed to `AstTypePack` if it is any type pack node, or `nil` otherwise. |
| [isTypePackExplicit](#utilsistypepackexplicit) | Returns `n` narrowed to `AstTypePackExplicit` if it is an explicit type pack, or `nil` otherwise. |
| [isTypePackGeneric](#utilsistypepackgeneric) | Returns `n` narrowed to `AstTypePackGeneric` if it is a generic type pack, or `nil` otherwise. |
| [isTypePackVariadic](#utilsistypepackvariadic) | Returns `n` narrowed to `AstTypePackVariadic` if it is a variadic type pack, or `nil` otherwise. |
| [isTypeReference](#utilsistypereference) | Returns `n` narrowed to `AstTypeReference` if it is a type reference, or `nil` otherwise. |
| [isTypeSingletonBool](#utilsistypesingletonbool) | Returns `n` narrowed to `AstTypeSingletonBool` if it is a boolean singleton type, or `nil` otherwise. |
| [isTypeSingletonString](#utilsistypesingletonstring) | Returns `n` narrowed to `AstTypeSingletonString` if it is a string singleton type, or `nil` otherwise. |
| [isTypeTable](#utilsistypetable) | Returns `n` narrowed to `AstTypeTable` if it is a table type, or `nil` otherwise. |
| [isTypeTypeof](#utilsistypetypeof) | Returns `n` narrowed to `AstTypeTypeof` if it is a `typeof(...)` type, or `nil` otherwise. |
| [isTypeUnion](#utilsistypeunion) | Returns `n` narrowed to `AstTypeUnion` if it is a type union, or `nil` otherwise. |

---

## Functions and Properties

### utils.isAttribute

Returns `n` narrowed to `AstAttribute` if it is an attribute node, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstAttribute?
```

---

### utils.isExpr

Returns `n` narrowed to `AstExpr` if it is any expression node, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExpr?
```

---

### utils.isExprBinary

Returns `n` narrowed to `AstExprBinary` if it is a binary expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprBinary?
```

---

### utils.isExprCall

Returns `n` narrowed to `AstExprCall` if it is a call expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprCall?
```

---

### utils.isExprConstantBool

Returns `n` narrowed to `AstExprConstantBool` if it is a boolean literal expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprConstantBool?
```

---

### utils.isExprConstantNil

Returns `n` narrowed to `AstExprConstantNil` if it is a nil literal expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprConstantNil?
```

---

### utils.isExprConstantNumber

Returns `n` narrowed to `AstExprConstantNumber` if it is a number literal expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprConstantNumber?
```

---

### utils.isExprConstantString

Returns `n` narrowed to `AstExprConstantString` if it is a string literal expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprConstantString?
```

---

### utils.isExprFunction

Returns `n` narrowed to `AstExprFunction` if it is a function expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprFunction?
```

---

### utils.isExprGlobal

Returns `n` narrowed to `AstExprGlobal` if it is a global variable reference expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprGlobal?
```

---

### utils.isExprGroup

Returns `n` narrowed to `AstExprGroup` if it is a parenthesized expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprGroup?
```

---

### utils.isExprIfElse

Returns `n` narrowed to `AstExprIfElse` if it is an `if-then-else` expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprIfElse?
```

---

### utils.isExprIndexExpr

Returns `n` narrowed to `AstExprIndexExpr` if it is an index expression (e.g. `a[b]`), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprIndexExpr?
```

---

### utils.isExprIndexName

Returns `n` narrowed to `AstExprIndexName` if it is a field access expression (e.g. `a.b`), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprIndexName?
```

---

### utils.isExprInterpString

Returns `n` narrowed to `AstExprInterpString` if it is an interpolated string expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprInterpString?
```

---

### utils.isExprLocal

Returns `n` narrowed to `AstExprLocal` if it is a local variable reference expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprLocal?
```

---

### utils.isExprTable

Returns `n` narrowed to `AstExprTable` if it is a table constructor expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprTable?
```

---

### utils.isExprTypeAssertion

Returns `n` narrowed to `AstExprTypeAssertion` if it is a type assertion expression (`expr :: Type`), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprTypeAssertion?
```

---

### utils.isExprUnary

Returns `n` narrowed to `AstExprUnary` if it is a unary expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprUnary?
```

---

### utils.isExprVarargs

Returns `n` narrowed to `AstExprVarargs` if it is a varargs expression (`...`), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprVarargs?
```

---

### utils.isGenericType

Returns `n` narrowed to `AstGenericType` if it is a generic type parameter, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstGenericType?
```

---

### utils.isGenericTypePack

Returns `n` narrowed to `AstGenericTypePack` if it is a generic type pack parameter, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstGenericTypePack?
```

---

### utils.isLocal

Returns `n` narrowed to `AstLocal` if it is a local variable node, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstLocal?
```

---

### utils.isRequireCall

Returns `n` as an `AstExprCall` if it is a `require(...)` call expression, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstExprCall?
```

---

### utils.isStat

Returns `n` narrowed to `AstStat` if it is any statement node, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStat?
```

---

### utils.isStatAssign

Returns `n` narrowed to `AstStatAssign` if it is an assignment statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatAssign?
```

---

### utils.isStatBlock

Returns `n` narrowed to `AstStatBlock` if it is a block statement (do...end), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatBlock?
```

---

### utils.isStatBreak

Returns `n` narrowed to `AstStatBreak` if it is a break statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatBreak?
```

---

### utils.isStatCompoundAssign

Returns `n` narrowed to `AstStatCompoundAssign` if it is a compound assignment statement (e.g. `+=`), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatCompoundAssign?
```

---

### utils.isStatContinue

Returns `n` narrowed to `AstStatContinue` if it is a continue statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatContinue?
```

---

### utils.isStatExpr

Returns `n` narrowed to `AstStatExpr` if it is an expression statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatExpr?
```

---

### utils.isStatFor

Returns `n` narrowed to `AstStatFor` if it is a numeric for statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatFor?
```

---

### utils.isStatForIn

Returns `n` narrowed to `AstStatForIn` if it is a generic for-in statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatForIn?
```

---

### utils.isStatFunction

Returns `n` narrowed to `AstStatFunction` if it is a function declaration statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatFunction?
```

---

### utils.isStatIf

Returns `n` narrowed to `AstStatIf` if it is an if statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatIf?
```

---

### utils.isStatLocal

Returns `n` narrowed to `AstStatLocal` if it is a local variable declaration, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatLocal?
```

---

### utils.isStatLocalFunction

Returns `n` narrowed to `AstStatLocalFunction` if it is a local function declaration, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatLocalFunction?
```

---

### utils.isStatRepeat

Returns `n` narrowed to `AstStatRepeat` if it is a repeat-until statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatRepeat?
```

---

### utils.isStatReturn

Returns `n` narrowed to `AstStatReturn` if it is a return statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatReturn?
```

---

### utils.isStatTypeAlias

Returns `n` narrowed to `AstStatTypeAlias` if it is a type alias declaration, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatTypeAlias?
```

---

### utils.isStatTypeFunction

Returns `n` narrowed to `AstStatTypeFunction` if it is a type function declaration, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatTypeFunction?
```

---

### utils.isStatWhile

Returns `n` narrowed to `AstStatWhile` if it is a while statement, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstStatWhile?
```

---

### utils.isTableExprItem

Returns `n` narrowed to `AstTableExprItem` if it is a table constructor item, or `nil` otherwise.

```luau
(n: types.AstNode | types.AstTableExprItem) -> types.AstTableExprItem?
```

---

### utils.isToken

Returns `n` narrowed to `Token` if it is a token, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.Token?
```

---

### utils.isType

Returns `n` narrowed to `AstType` if it is any type annotation node, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstType?
```

---

### utils.isTypeArray

Returns `n` narrowed to `AstTypeArray` if it is an array type (`{T}`), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeArray?
```

---

### utils.isTypeFunction

Returns `n` narrowed to `AstTypeFunction` if it is a function type, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeFunction?
```

---

### utils.isTypeGroup

Returns `n` narrowed to `AstTypeGroup` if it is a parenthesized type, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeGroup?
```

---

### utils.isTypeIntersection

Returns `n` narrowed to `AstTypeIntersection` if it is a type intersection, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeIntersection?
```

---

### utils.isTypeOptional

Returns `n` narrowed to `AstTypeOptional` if it is an optional type (`T?`), or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeOptional?
```

---

### utils.isTypePack

Returns `n` narrowed to `AstTypePack` if it is any type pack node, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypePack?
```

---

### utils.isTypePackExplicit

Returns `n` narrowed to `AstTypePackExplicit` if it is an explicit type pack, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypePackExplicit?
```

---

### utils.isTypePackGeneric

Returns `n` narrowed to `AstTypePackGeneric` if it is a generic type pack, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypePackGeneric?
```

---

### utils.isTypePackVariadic

Returns `n` narrowed to `AstTypePackVariadic` if it is a variadic type pack, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypePackVariadic?
```

---

### utils.isTypeReference

Returns `n` narrowed to `AstTypeReference` if it is a type reference, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeReference?
```

---

### utils.isTypeSingletonBool

Returns `n` narrowed to `AstTypeSingletonBool` if it is a boolean singleton type, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeSingletonBool?
```

---

### utils.isTypeSingletonString

Returns `n` narrowed to `AstTypeSingletonString` if it is a string singleton type, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeSingletonString?
```

---

### utils.isTypeTable

Returns `n` narrowed to `AstTypeTable` if it is a table type, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeTable?
```

---

### utils.isTypeTypeof

Returns `n` narrowed to `AstTypeTypeof` if it is a `typeof(...)` type, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeTypeof?
```

---

### utils.isTypeUnion

Returns `n` narrowed to `AstTypeUnion` if it is a type union, or `nil` otherwise.

```luau
(n: types.AstNode) -> types.AstTypeUnion?
```

---
