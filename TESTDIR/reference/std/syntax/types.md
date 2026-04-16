# types

```luau
local types = require("@std/syntax/types")
```

## Summary

| Entry | Description |
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
| [Replacements](#replacements) |  |
| [SingleLineComment](#singlelinecomment) |  |
| [Span](#span) |  |
| [Trivia](#trivia) |  |
| [Type](#type) |  |
| [TypePack](#typepack) |  |
| [Whitespace](#whitespace) |  |

---

## Types

### AstAttribute

```luau
type AstAttribute = luau.AstAttribute
```

---

### AstElseIfExpr

```luau
type AstElseIfExpr = luau.AstElseIfExpr
```

---

### AstElseIfStat

```luau
type AstElseIfStat = luau.AstElseIfStat
```

---

### AstExpr

```luau
type AstExpr = luau.AstExpr
```

---

### AstExprBinary

```luau
type AstExprBinary = luau.AstExprBinary
```

---

### AstExprCall

```luau
type AstExprCall = luau.AstExprCall
```

---

### AstExprConstantBool

```luau
type AstExprConstantBool = luau.AstExprConstantBool
```

---

### AstExprConstantNil

```luau
type AstExprConstantNil = luau.AstExprConstantNil
```

---

### AstExprConstantNumber

```luau
type AstExprConstantNumber = luau.AstExprConstantNumber
```

---

### AstExprConstantString

```luau
type AstExprConstantString = luau.AstExprConstantString
```

---

### AstExprFunction

```luau
type AstExprFunction = luau.AstExprFunction
```

---

### AstExprGlobal

```luau
type AstExprGlobal = luau.AstExprGlobal
```

---

### AstExprGroup

```luau
type AstExprGroup = luau.AstExprGroup
```

---

### AstExprIfElse

```luau
type AstExprIfElse = luau.AstExprIfElse
```

---

### AstExprIndexExpr

```luau
type AstExprIndexExpr = luau.AstExprIndexExpr
```

---

### AstExprIndexName

```luau
type AstExprIndexName = luau.AstExprIndexName
```

---

### AstExprInstantiate

```luau
type AstExprInstantiate = luau.AstExprInstantiate
```

---

### AstExprInterpString

```luau
type AstExprInterpString = luau.AstExprInterpString
```

---

### AstExprLocal

```luau
type AstExprLocal = luau.AstExprLocal
```

---

### AstExprTable

```luau
type AstExprTable = luau.AstExprTable
```

---

### AstExprTypeAssertion

```luau
type AstExprTypeAssertion = luau.AstExprTypeAssertion
```

---

### AstExprUnary

```luau
type AstExprUnary = luau.AstExprUnary
```

---

### AstExprVarargs

```luau
type AstExprVarargs = luau.AstExprVarargs
```

---

### AstFunctionTypeParameter

```luau
type AstFunctionTypeParameter = luau.AstFunctionTypeParameter
```

---

### AstGenericType

```luau
type AstGenericType = luau.AstGenericType
```

---

### AstGenericTypePack

```luau
type AstGenericTypePack = luau.AstGenericTypePack
```

---

### AstLocal

```luau
type AstLocal = luau.AstLocal
```

---

### AstNode

```luau
type AstNode = luau.AstNode
```

---

### AstStat

```luau
type AstStat = luau.AstStat
```

---

### AstStatAssign

```luau
type AstStatAssign = luau.AstStatAssign
```

---

### AstStatBlock

```luau
type AstStatBlock = luau.AstStatBlock
```

---

### AstStatBreak

```luau
type AstStatBreak = luau.AstStatBreak
```

---

### AstStatCompoundAssign

```luau
type AstStatCompoundAssign = luau.AstStatCompoundAssign
```

---

### AstStatContinue

```luau
type AstStatContinue = luau.AstStatContinue
```

---

### AstStatDo

```luau
type AstStatDo = luau.AstStatDo
```

---

### AstStatExpr

```luau
type AstStatExpr = luau.AstStatExpr
```

---

### AstStatFor

```luau
type AstStatFor = luau.AstStatFor
```

---

### AstStatForIn

```luau
type AstStatForIn = luau.AstStatForIn
```

---

### AstStatFunction

```luau
type AstStatFunction = luau.AstStatFunction
```

---

### AstStatIf

```luau
type AstStatIf = luau.AstStatIf
```

---

### AstStatLocal

```luau
type AstStatLocal = luau.AstStatLocal
```

---

### AstStatLocalFunction

```luau
type AstStatLocalFunction = luau.AstStatLocalFunction
```

---

### AstStatRepeat

```luau
type AstStatRepeat = luau.AstStatRepeat
```

---

### AstStatReturn

```luau
type AstStatReturn = luau.AstStatReturn
```

---

### AstStatTypeAlias

```luau
type AstStatTypeAlias = luau.AstStatTypeAlias
```

---

### AstStatTypeFunction

```luau
type AstStatTypeFunction = luau.AstStatTypeFunction
```

---

### AstStatWhile

```luau
type AstStatWhile = luau.AstStatWhile
```

---

### AstTableExprGeneralItem

```luau
type AstTableExprGeneralItem = luau.AstTableExprGeneralItem
```

---

### AstTableExprItem

```luau
type AstTableExprItem = luau.AstTableExprItem
```

---

### AstTableExprListItem

```luau
type AstTableExprListItem = luau.AstTableExprListItem
```

---

### AstTableExprRecordItem

```luau
type AstTableExprRecordItem = luau.AstTableExprRecordItem
```

---

### AstTableTypeItem

```luau
type AstTableTypeItem = luau.AstTableTypeItem
```

---

### AstTableTypeItemIndexer

```luau
type AstTableTypeItemIndexer = luau.AstTableTypeItemIndexer
```

---

### AstTableTypeItemProperty

```luau
type AstTableTypeItemProperty = luau.AstTableTypeItemProperty
```

---

### AstTableTypeItemStringProperty

```luau
type AstTableTypeItemStringProperty = luau.AstTableTypeItemStringProperty
```

---

### AstType

```luau
type AstType = luau.AstType
```

---

### AstTypeArray

```luau
type AstTypeArray = luau.AstTypeArray
```

---

### AstTypeFunction

```luau
type AstTypeFunction = luau.AstTypeFunction
```

---

### AstTypeGroup

```luau
type AstTypeGroup = luau.AstTypeGroup
```

---

### AstTypeIntersection

```luau
type AstTypeIntersection = luau.AstTypeIntersection
```

---

### AstTypeOptional

```luau
type AstTypeOptional = luau.AstTypeOptional
```

---

### AstTypePack

```luau
type AstTypePack = luau.AstTypePack
```

---

### AstTypePackExplicit

```luau
type AstTypePackExplicit = luau.AstTypePackExplicit
```

---

### AstTypePackGeneric

```luau
type AstTypePackGeneric = luau.AstTypePackGeneric
```

---

### AstTypePackVariadic

```luau
type AstTypePackVariadic = luau.AstTypePackVariadic
```

---

### AstTypeReference

```luau
type AstTypeReference = luau.AstTypeReference
```

---

### AstTypeSingletonBool

```luau
type AstTypeSingletonBool = luau.AstTypeSingletonBool
```

---

### AstTypeSingletonString

```luau
type AstTypeSingletonString = luau.AstTypeSingletonString
```

---

### AstTypeTable

```luau
type AstTypeTable = luau.AstTypeTable
```

---

### AstTypeTypeof

```luau
type AstTypeTypeof = luau.AstTypeTypeof
```

---

### AstTypeUnion

```luau
type AstTypeUnion = luau.AstTypeUnion
```

---

### Eof

```luau
type Eof = luau.Eof
```

---

### MultiLineComment

```luau
type MultiLineComment = luau.MultiLineComment
```

---

### ParseResult

```luau
type ParseResult = luau.ParseResult
```

---

### Replacements

```luau
type Replacements = { [AstNode]: string }
```

---

### SingleLineComment

```luau
type SingleLineComment = luau.SingleLineComment
```

---

### Span

```luau
type Span = luau.Span
```

---

### Trivia

```luau
type Trivia = luau.Trivia
```

---

### Type

```luau
type Type = luau.Type
```

---

### TypePack

```luau
type TypePack = luau.TypePack
```

---

### Whitespace

```luau
type Whitespace = luau.Whitespace
```

---
