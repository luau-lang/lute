# syntax

```luau
local syntax = require("@std/syntax")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [AstAttribute](#astattribute) |  |
| [AstElseIfExpr](#astelseifexpr) |  |
| [AstElseIfStat](#astelseifstat) |  |
| [AstExpr](#astexpr) |  |
| [AstExprBinary](#astexprbinary) |  |
| [AstExprCall](#astexprcall) |  |
| [AstExprConstantBool](#astexprconstantbool) |  |
| [AstExprConstantNil](#astexprconstantnil) |  |
| [AstExprConstantNumber](#astexprconstantnumber) |  |
| [AstExprConstantString](#astexprconstantstring) |  |
| [AstExprFunction](#astexprfunction) |  |
| [AstExprGlobal](#astexprglobal) |  |
| [AstExprGroup](#astexprgroup) |  |
| [AstExprIfElse](#astexprifelse) |  |
| [AstExprIndexExpr](#astexprindexexpr) |  |
| [AstExprIndexName](#astexprindexname) |  |
| [AstExprInstantiate](#astexprinstantiate) |  |
| [AstExprInterpString](#astexprinterpstring) |  |
| [AstExprLocal](#astexprlocal) |  |
| [AstExprTable](#astexprtable) |  |
| [AstExprTypeAssertion](#astexprtypeassertion) |  |
| [AstExprUnary](#astexprunary) |  |
| [AstExprVarargs](#astexprvarargs) |  |
| [AstFunctionTypeParameter](#astfunctiontypeparameter) |  |
| [AstGenericType](#astgenerictype) |  |
| [AstGenericTypePack](#astgenerictypepack) |  |
| [AstLocal](#astlocal) |  |
| [AstNode](#astnode) |  |
| [AstStat](#aststat) |  |
| [AstStatAssign](#aststatassign) |  |
| [AstStatBlock](#aststatblock) |  |
| [AstStatBreak](#aststatbreak) |  |
| [AstStatCompoundAssign](#aststatcompoundassign) |  |
| [AstStatContinue](#aststatcontinue) |  |
| [AstStatDo](#aststatdo) |  |
| [AstStatExpr](#aststatexpr) |  |
| [AstStatFor](#aststatfor) |  |
| [AstStatForIn](#aststatforin) |  |
| [AstStatFunction](#aststatfunction) |  |
| [AstStatIf](#aststatif) |  |
| [AstStatLocal](#aststatlocal) |  |
| [AstStatLocalFunction](#aststatlocalfunction) |  |
| [AstStatRepeat](#aststatrepeat) |  |
| [AstStatReturn](#aststatreturn) |  |
| [AstStatTypeAlias](#aststattypealias) |  |
| [AstStatTypeFunction](#aststattypefunction) |  |
| [AstStatWhile](#aststatwhile) |  |
| [AstTableExprGeneralItem](#asttableexprgeneralitem) |  |
| [AstTableExprItem](#asttableexpritem) |  |
| [AstTableExprListItem](#asttableexprlistitem) |  |
| [AstTableExprRecordItem](#asttableexprrecorditem) |  |
| [AstTableTypeItem](#asttabletypeitem) |  |
| [AstTableTypeItemIndexer](#asttabletypeitemindexer) |  |
| [AstTableTypeItemProperty](#asttabletypeitemproperty) |  |
| [AstTableTypeItemStringProperty](#asttabletypeitemstringproperty) |  |
| [AstType](#asttype) |  |
| [AstTypeArray](#asttypearray) |  |
| [AstTypeFunction](#asttypefunction) |  |
| [AstTypeGroup](#asttypegroup) |  |
| [AstTypeIntersection](#asttypeintersection) |  |
| [AstTypeOptional](#asttypeoptional) |  |
| [AstTypePack](#asttypepack) |  |
| [AstTypePackExplicit](#asttypepackexplicit) |  |
| [AstTypePackGeneric](#asttypepackgeneric) |  |
| [AstTypePackVariadic](#asttypepackvariadic) |  |
| [AstTypeReference](#asttypereference) |  |
| [AstTypeSingletonBool](#asttypesingletonbool) |  |
| [AstTypeSingletonString](#asttypesingletonstring) |  |
| [AstTypeTable](#asttypetable) |  |
| [AstTypeTypeof](#asttypetypeof) |  |
| [AstTypeUnion](#asttypeunion) |  |
| [Eof](#eof) |  |
| [MultiLineComment](#multilinecomment) |  |
| [ParseResult](#parseresult) |  |
| [SingleLineComment](#singlelinecomment) |  |
| [Span](#span) |  |
| [Trivia](#trivia) |  |
| [Whitespace](#whitespace) |  |

---

## Types

### AstAttribute

```luau
type AstAttribute = types.AstAttribute
```

---

### AstElseIfExpr

```luau
type AstElseIfExpr = types.AstElseIfExpr
```

---

### AstElseIfStat

```luau
type AstElseIfStat = types.AstElseIfStat
```

---

### AstExpr

```luau
type AstExpr = types.AstExpr
```

---

### AstExprBinary

```luau
type AstExprBinary = types.AstExprBinary
```

---

### AstExprCall

```luau
type AstExprCall = types.AstExprCall
```

---

### AstExprConstantBool

```luau
type AstExprConstantBool = types.AstExprConstantBool
```

---

### AstExprConstantNil

```luau
type AstExprConstantNil = types.AstExprConstantNil
```

---

### AstExprConstantNumber

```luau
type AstExprConstantNumber = types.AstExprConstantNumber
```

---

### AstExprConstantString

```luau
type AstExprConstantString = types.AstExprConstantString
```

---

### AstExprFunction

```luau
type AstExprFunction = types.AstExprFunction
```

---

### AstExprGlobal

```luau
type AstExprGlobal = types.AstExprGlobal
```

---

### AstExprGroup

```luau
type AstExprGroup = types.AstExprGroup
```

---

### AstExprIfElse

```luau
type AstExprIfElse = types.AstExprIfElse
```

---

### AstExprIndexExpr

```luau
type AstExprIndexExpr = types.AstExprIndexExpr
```

---

### AstExprIndexName

```luau
type AstExprIndexName = types.AstExprIndexName
```

---

### AstExprInstantiate

```luau
type AstExprInstantiate = types.AstExprInstantiate
```

---

### AstExprInterpString

```luau
type AstExprInterpString = types.AstExprInterpString
```

---

### AstExprLocal

```luau
type AstExprLocal = types.AstExprLocal
```

---

### AstExprTable

```luau
type AstExprTable = types.AstExprTable
```

---

### AstExprTypeAssertion

```luau
type AstExprTypeAssertion = types.AstExprTypeAssertion
```

---

### AstExprUnary

```luau
type AstExprUnary = types.AstExprUnary
```

---

### AstExprVarargs

```luau
type AstExprVarargs = types.AstExprVarargs
```

---

### AstFunctionTypeParameter

```luau
type AstFunctionTypeParameter = types.AstFunctionTypeParameter
```

---

### AstGenericType

```luau
type AstGenericType = types.AstGenericType
```

---

### AstGenericTypePack

```luau
type AstGenericTypePack = types.AstGenericTypePack
```

---

### AstLocal

```luau
type AstLocal = types.AstLocal
```

---

### AstNode

```luau
type AstNode = types.AstNode
```

---

### AstStat

```luau
type AstStat = types.AstStat
```

---

### AstStatAssign

```luau
type AstStatAssign = types.AstStatAssign
```

---

### AstStatBlock

```luau
type AstStatBlock = types.AstStatBlock
```

---

### AstStatBreak

```luau
type AstStatBreak = types.AstStatBreak
```

---

### AstStatCompoundAssign

```luau
type AstStatCompoundAssign = types.AstStatCompoundAssign
```

---

### AstStatContinue

```luau
type AstStatContinue = types.AstStatContinue
```

---

### AstStatDo

```luau
type AstStatDo = types.AstStatDo
```

---

### AstStatExpr

```luau
type AstStatExpr = types.AstStatExpr
```

---

### AstStatFor

```luau
type AstStatFor = types.AstStatFor
```

---

### AstStatForIn

```luau
type AstStatForIn = types.AstStatForIn
```

---

### AstStatFunction

```luau
type AstStatFunction = types.AstStatFunction
```

---

### AstStatIf

```luau
type AstStatIf = types.AstStatIf
```

---

### AstStatLocal

```luau
type AstStatLocal = types.AstStatLocal
```

---

### AstStatLocalFunction

```luau
type AstStatLocalFunction = types.AstStatLocalFunction
```

---

### AstStatRepeat

```luau
type AstStatRepeat = types.AstStatRepeat
```

---

### AstStatReturn

```luau
type AstStatReturn = types.AstStatReturn
```

---

### AstStatTypeAlias

```luau
type AstStatTypeAlias = types.AstStatTypeAlias
```

---

### AstStatTypeFunction

```luau
type AstStatTypeFunction = types.AstStatTypeFunction
```

---

### AstStatWhile

```luau
type AstStatWhile = types.AstStatWhile
```

---

### AstTableExprGeneralItem

```luau
type AstTableExprGeneralItem = types.AstTableExprGeneralItem
```

---

### AstTableExprItem

```luau
type AstTableExprItem = types.AstTableExprItem
```

---

### AstTableExprListItem

```luau
type AstTableExprListItem = types.AstTableExprListItem
```

---

### AstTableExprRecordItem

```luau
type AstTableExprRecordItem = types.AstTableExprRecordItem
```

---

### AstTableTypeItem

```luau
type AstTableTypeItem = types.AstTableTypeItem
```

---

### AstTableTypeItemIndexer

```luau
type AstTableTypeItemIndexer = types.AstTableTypeItemIndexer
```

---

### AstTableTypeItemProperty

```luau
type AstTableTypeItemProperty = types.AstTableTypeItemProperty
```

---

### AstTableTypeItemStringProperty

```luau
type AstTableTypeItemStringProperty = types.AstTableTypeItemStringProperty
```

---

### AstType

```luau
type AstType = types.AstType
```

---

### AstTypeArray

```luau
type AstTypeArray = types.AstTypeArray
```

---

### AstTypeFunction

```luau
type AstTypeFunction = types.AstTypeFunction
```

---

### AstTypeGroup

```luau
type AstTypeGroup = types.AstTypeGroup
```

---

### AstTypeIntersection

```luau
type AstTypeIntersection = types.AstTypeIntersection
```

---

### AstTypeOptional

```luau
type AstTypeOptional = types.AstTypeOptional
```

---

### AstTypePack

```luau
type AstTypePack = types.AstTypePack
```

---

### AstTypePackExplicit

```luau
type AstTypePackExplicit = types.AstTypePackExplicit
```

---

### AstTypePackGeneric

```luau
type AstTypePackGeneric = types.AstTypePackGeneric
```

---

### AstTypePackVariadic

```luau
type AstTypePackVariadic = types.AstTypePackVariadic
```

---

### AstTypeReference

```luau
type AstTypeReference = types.AstTypeReference
```

---

### AstTypeSingletonBool

```luau
type AstTypeSingletonBool = types.AstTypeSingletonBool
```

---

### AstTypeSingletonString

```luau
type AstTypeSingletonString = types.AstTypeSingletonString
```

---

### AstTypeTable

```luau
type AstTypeTable = types.AstTypeTable
```

---

### AstTypeTypeof

```luau
type AstTypeTypeof = types.AstTypeTypeof
```

---

### AstTypeUnion

```luau
type AstTypeUnion = types.AstTypeUnion
```

---

### Eof

```luau
type Eof = types.Eof
```

---

### MultiLineComment

```luau
type MultiLineComment = types.MultiLineComment
```

---

### ParseResult

```luau
type ParseResult = types.ParseResult
```

---

### SingleLineComment

```luau
type SingleLineComment = types.SingleLineComment
```

---

### Span

```luau
type Span = types.Span
```

---

### Trivia

```luau
type Trivia = types.Trivia
```

---

### Whitespace

```luau
type Whitespace = types.Whitespace
```

---
