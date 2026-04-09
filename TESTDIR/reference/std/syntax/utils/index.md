# utils

```luau
local utils = require("@std/syntax/utils")
```

## utils.isAttribute

```luau
(n: types.AstNode) -> types.AstAttribute?
```

## utils.isExpr

```luau
(n: types.AstNode) -> types.AstExpr?
```

## utils.isExprBinary

```luau
(n: types.AstNode) -> types.AstExprBinary?
```

## utils.isExprCall

```luau
(n: types.AstNode) -> types.AstExprCall?
```

## utils.isExprConstantBool

```luau
(n: types.AstNode) -> types.AstExprConstantBool?
```

## utils.isExprConstantNil

```luau
(n: types.AstNode) -> types.AstExprConstantNil?
```

## utils.isExprConstantNumber

```luau
(n: types.AstNode) -> types.AstExprConstantNumber?
```

## utils.isExprConstantString

```luau
(n: types.AstNode) -> types.AstExprConstantString?
```

## utils.isExprFunction

```luau
(n: types.AstNode) -> types.AstExprFunction?
```

## utils.isExprGlobal

```luau
(n: types.AstNode) -> types.AstExprGlobal?
```

## utils.isExprGroup

```luau
(n: types.AstNode) -> types.AstExprGroup?
```

## utils.isExprIfElse

```luau
(n: types.AstNode) -> types.AstExprIfElse?
```

## utils.isExprIndexExpr

```luau
(n: types.AstNode) -> types.AstExprIndexExpr?
```

## utils.isExprIndexName

```luau
(n: types.AstNode) -> types.AstExprIndexName?
```

## utils.isExprInterpString

```luau
(n: types.AstNode) -> types.AstExprInterpString?
```

## utils.isExprLocal

```luau
(n: types.AstNode) -> types.AstExprLocal?
```

## utils.isExprTable

```luau
(n: types.AstNode) -> types.AstExprTable?
```

## utils.isExprTypeAssertion

```luau
(n: types.AstNode) -> types.AstExprTypeAssertion?
```

## utils.isExprUnary

```luau
(n: types.AstNode) -> types.AstExprUnary?
```

## utils.isExprVarargs

```luau
(n: types.AstNode) -> types.AstExprVarargs?
```

## utils.isGenericType

```luau
(n: types.AstNode) -> types.AstGenericType?
```

## utils.isGenericTypePack

```luau
(n: types.AstNode) -> types.AstGenericTypePack?
```

## utils.isLocal

```luau
(n: types.AstNode) -> types.AstLocal?
```

## utils.isRequireCall

```luau
(n: types.AstNode) -> types.AstExprCall?
```

## utils.isStat

```luau
(n: types.AstNode) -> types.AstStat?
```

## utils.isStatAssign

```luau
(n: types.AstNode) -> types.AstStatAssign?
```

## utils.isStatBlock

```luau
(n: types.AstNode) -> types.AstStatBlock?
```

## utils.isStatBreak

```luau
(n: types.AstNode) -> types.AstStatBreak?
```

## utils.isStatCompoundAssign

```luau
(n: types.AstNode) -> types.AstStatCompoundAssign?
```

## utils.isStatContinue

```luau
(n: types.AstNode) -> types.AstStatContinue?
```

## utils.isStatExpr

```luau
(n: types.AstNode) -> types.AstStatExpr?
```

## utils.isStatFor

```luau
(n: types.AstNode) -> types.AstStatFor?
```

## utils.isStatForIn

```luau
(n: types.AstNode) -> types.AstStatForIn?
```

## utils.isStatFunction

```luau
(n: types.AstNode) -> types.AstStatFunction?
```

## utils.isStatIf

```luau
(n: types.AstNode) -> types.AstStatIf?
```

## utils.isStatLocal

```luau
(n: types.AstNode) -> types.AstStatLocal?
```

## utils.isStatLocalFunction

```luau
(n: types.AstNode) -> types.AstStatLocalFunction?
```

## utils.isStatRepeat

```luau
(n: types.AstNode) -> types.AstStatRepeat?
```

## utils.isStatReturn

```luau
(n: types.AstNode) -> types.AstStatReturn?
```

## utils.isStatTypeAlias

```luau
(n: types.AstNode) -> types.AstStatTypeAlias?
```

## utils.isStatTypeFunction

```luau
(n: types.AstNode) -> types.AstStatTypeFunction?
```

## utils.isStatWhile

```luau
(n: types.AstNode) -> types.AstStatWhile?
```

## utils.isTableExprItem

```luau
(n: types.AstNode | types.AstTableExprItem) -> types.AstTableExprItem?
```

## utils.isToken

```luau
(n: types.AstNode) -> types.Token?
```

## utils.isType

```luau
(n: types.AstNode) -> types.AstType?
```

## utils.isTypeArray

```luau
(n: types.AstNode) -> types.AstTypeArray?
```

## utils.isTypeFunction

```luau
(n: types.AstNode) -> types.AstTypeFunction?
```

## utils.isTypeGroup

```luau
(n: types.AstNode) -> types.AstTypeGroup?
```

## utils.isTypeIntersection

```luau
(n: types.AstNode) -> types.AstTypeIntersection?
```

## utils.isTypeOptional

```luau
(n: types.AstNode) -> types.AstTypeOptional?
```

## utils.isTypePack

```luau
(n: types.AstNode) -> types.AstTypePack?
```

## utils.isTypePackExplicit

```luau
(n: types.AstNode) -> types.AstTypePackExplicit?
```

## utils.isTypePackGeneric

```luau
(n: types.AstNode) -> types.AstTypePackGeneric?
```

## utils.isTypePackVariadic

```luau
(n: types.AstNode) -> types.AstTypePackVariadic?
```

## utils.isTypeReference

```luau
(n: types.AstNode) -> types.AstTypeReference?
```

## utils.isTypeSingletonBool

```luau
(n: types.AstNode) -> types.AstTypeSingletonBool?
```

## utils.isTypeSingletonString

```luau
(n: types.AstNode) -> types.AstTypeSingletonString?
```

## utils.isTypeTable

```luau
(n: types.AstNode) -> types.AstTypeTable?
```

## utils.isTypeTypeof

```luau
(n: types.AstNode) -> types.AstTypeTypeof?
```

## utils.isTypeUnion

```luau
(n: types.AstNode) -> types.AstTypeUnion?
```
