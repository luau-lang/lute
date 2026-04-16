# luau

```luau
local luau = require("@lute/luau")
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
| [Bytecode](#bytecode) |  |
| [Eof](#eof) |  |
| [MultiLineComment](#multilinecomment) |  |
| [ParseResult](#parseresult) |  |
| [SingleLineComment](#singlelinecomment) |  |
| [Span](#span) |  |
| [Trivia](#trivia) |  |
| [Type](#type) |  |
| [TypePack](#typepack) |  |
| [Whitespace](#whitespace) |  |
| [compile](#luaucompile) |  |
| [load](#luauload) |  |
| [parse](#luauparse) |  |
| [parseExpr](#luauparseexpr) |  |
| [resolveModule](#luauresolvemodule) |  |
| [span.create](#luauspancreate) |  |
| [typeofModule](#luautypeofmodule) |  |

---

## Types

### AstAttribute

```luau
type AstAttribute = {
	read location: Span,
	read kind: "attribute",
	read token: Token<"@checked" | "@native" | "@deprecated">,
}
```

---

### AstElseIfExpr

```luau
type AstElseIfExpr = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenExpr: AstExpr,
}
```

---

### AstElseIfStat

```luau
type AstElseIfStat = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenBlock: AstStatBlock,
}
```

---

### AstExpr

```luau
type AstExpr = 
```

---

### AstExprBinary

```luau
type AstExprBinary = {
	read location: Span,
	read kind: "expr",
	read tag: "binary",
	read lhsOperand: AstExpr,
	read operator: Token,
	read rhsOperand: AstExpr,
}
```

---

### AstExprCall

```luau
type AstExprCall = {
	read location: Span,
	read kind: "expr",
	read tag: "call",
	read func: AstExpr,
	read openParens: Token<"(">?,
	read arguments: Punctuated<AstExpr>,
	read closeParens: Token<")">?,
	read self: boolean,
	read argLocation: Span,
}
```

---

### AstExprConstantBool

```luau
type AstExprConstantBool = {
	read location: Span,
	read kind: "expr",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}
```

---

### AstExprConstantNil

```luau
type AstExprConstantNil = {
	read location: Span,
	read kind: "expr",
	read tag: "nil",
	read token: Token<"nil">,
}
```

---

### AstExprConstantNumber

```luau
type AstExprConstantNumber = {
	read location: Span,
	read kind: "expr",
	read tag: "number",
	read value: number,
	read token: Token<string>,
}
```

---

### AstExprConstantString

```luau
type AstExprConstantString = {
	read location: Span,
	read kind: "expr",
	read tag: "string",
	read quoteStyle: "single" | "double" | "block" | "interp",
	read blockDepth: number,
	read token: Token<string>,
}
```

---

### AstExprFunction

```luau
type AstExprFunction = {
	read location: Span,
	read kind: "expr",
	read tag: "function",
	read attributes: { AstAttribute },
	read functionKeyword: Token<"function">,
	read openGenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericPacks: Punctuated<AstGenericTypePack>?,
	read closeGenerics: Token<">">?,
	read openParens: Token<"(">,
	read self: AstLocal?,
	read parameters: Punctuated<AstLocal>,
	read vararg: Token<"...">?,
	read varargColon: Token<":">?,
	read varargAnnotation: AstTypePack?,
	read closeParens: Token<")">,
	read returnSpecifier: Token<":">?,
	read returnAnnotation: AstTypePack?,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}
```

---

### AstExprGlobal

```luau
type AstExprGlobal = { read location: Span, read kind: "expr", read tag: "global", read name: Token }
```

---

### AstExprGroup

```luau
type AstExprGroup = {
	read location: Span,
	read kind: "expr",
	read tag: "group",
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}
```

---

### AstExprIfElse

```luau
type AstExprIfElse = {
	read location: Span,
	read kind: "expr",
	read tag: "conditional",
	read ifKeyword: Token<"if">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenExpr: AstExpr,
	read elseifs: { AstElseIfExpr },
	read elseKeyword: Token<"else">,
	read elseExpr: AstExpr,
}
```

---

### AstExprIndexExpr

```luau
type AstExprIndexExpr = {
	read location: Span,
	read kind: "expr",
	read tag: "index",
	read expression: AstExpr,
	read openBrackets: Token<"[">,
	read index: AstExpr,
	read closeBrackets: Token<"]">,
}
```

---

### AstExprIndexName

```luau
type AstExprIndexName = {
	read location: Span,
	read kind: "expr",
	read tag: "indexname",
	read expression: AstExpr,
	read accessor: Token<"." | ":">,
	read index: Token<string>,
	read indexLocation: Span,
}
```

---

### AstExprInstantiate

```luau
type AstExprInstantiate = {
	read location: Span,
	read kind: "expr",
	read tag: "instantiate",
	read expr: AstExpr,
	read leftArrow1: Token<"<">,
	read leftArrow2: Token<"<">,
	read typeArguments: Punctuated<AstType | AstTypePack>,
	read rightArrow1: Token<">">,
	read rightArrow2: Token<">">,
}
```

---

### AstExprInterpString

```luau
type AstExprInterpString = {
	read location: Span,
	read kind: "expr",
	read tag: "interpolatedstring",
	read strings: { Token<string> },
	read expressions: { AstExpr },
}
```

---

### AstExprLocal

```luau
type AstExprLocal = {
	read location: Span,
	read kind: "expr",
	read tag: "local",
	read token: Token<string>,
	read ["local"]: AstLocal,
	read upvalue: boolean,
}
```

---

### AstExprTable

```luau
type AstExprTable = {
	read location: Span,
	read kind: "expr",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableExprItem },
	read closeBrace: Token<"}">,
}
```

---

### AstExprTypeAssertion

```luau
type AstExprTypeAssertion = {
	read location: Span,
	read kind: "expr",
	read tag: "cast",
	read operand: AstExpr,
	read operator: Token<"::">,
	read annotation: AstType,
}
```

---

### AstExprUnary

```luau
type AstExprUnary = {
	read location: Span,
	read kind: "expr",
	read tag: "unary",
	read operator: Token<"not" | "-" | "#">,
	read operand: AstExpr,
}
```

---

### AstExprVarargs

```luau
type AstExprVarargs = {
	read location: Span,
	read kind: "expr",
	read tag: "vararg",
	read token: Token<"...">,
}
```

---

### AstFunctionTypeParameter

```luau
type AstFunctionTypeParameter = {
	read location: Span,
	read name: Token?,
	read colon: Token<":">?,
	read type: AstType,
}
```

---

### AstGenericType

```luau
type AstGenericType = {
	read tag: "generic",
	read name: Token<string>,
	read equals: Token<"=">?,
	read default: AstType?,
}
```

---

### AstGenericTypePack

```luau
type AstGenericTypePack = {
	read tag: "genericpack",
	read name: Token<string>,
	read ellipsis: Token<"...">,
	read equals: Token<"=">?,
	read default: AstTypePack?,
}
```

---

### AstLocal

```luau
type AstLocal = {
	read location: Span,
	read kind: "local",
	read name: Token<string>,
	read colon: Token<":">?,
	read annotation: AstType?,
	read shadows: AstLocal?,
}
```

---

### AstNode

```luau
type AstNode = AstExpr | AstStat | AstType | AstTypePack | AstLocal | AstAttribute | Token
```

---

### AstStat

```luau
type AstStat = 
```

---

### AstStatAssign

```luau
type AstStatAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "assign",
	read variables: Punctuated<AstExpr>,
	read equals: Token<"=">,
	read values: Punctuated<AstExpr>,
}
```

---

### AstStatBlock

```luau
type AstStatBlock = {
	read location: Span,
	read kind: "stat",
	read tag: "block",
	read statements: { AstStat },
}
```

---

### AstStatBreak

```luau
type AstStatBreak = { read location: Span, read kind: "stat", read tag: "break", read token: Token<"break"> }
```

---

### AstStatCompoundAssign

```luau
type AstStatCompoundAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "compoundassign",
	read variable: AstExpr,
	read operand: Token, -- TODO: Enforce token type
	read value: AstExpr,
}
```

---

### AstStatContinue

```luau
type AstStatContinue = {
	read location: Span,
	read kind: "stat",
	read tag: "continue",
	read token: Token<"continue">,
}
```

---

### AstStatDo

```luau
type AstStatDo = {
	read location: Span,
	read kind: "stat",
	read tag: "do",
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}
```

---

### AstStatExpr

```luau
type AstStatExpr = {
	read location: Span,
	read kind: "stat",
	read tag: "expression",
	read expression: AstExpr,
}
```

---

### AstStatFor

```luau
type AstStatFor = {
	read location: Span,
	read kind: "stat",
	read tag: "for",
	read forKeyword: Token<"for">,
	read variable: AstLocal,
	read equals: Token<"=">,
	read from: AstExpr,
	read toComma: Token<",">,
	read to: AstExpr,
	read stepComma: Token<",">?,
	read step: AstExpr?,
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}
```

---

### AstStatForIn

```luau
type AstStatForIn = {
	read location: Span,
	read kind: "stat",
	read tag: "forin",
	read forKeyword: Token<"for">,
	read variables: Punctuated<AstLocal>,
	read inKeyword: Token<"in">,
	read values: Punctuated<AstExpr>,
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}
```

---

### AstStatFunction

```luau
type AstStatFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "function",
	read name: AstExpr,
	read func: AstExprFunction,
}
```

---

### AstStatIf

```luau
type AstStatIf = {
	read location: Span,
	read kind: "stat",
	read tag: "conditional",
	read ifKeyword: Token<"if">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenBlock: AstStatBlock,
	read elseifs: { AstElseIfStat },
	read elseKeyword: Token<"else">?, -- TODO: This could be elseif!
	read elseBlock: AstStatBlock?,
	read endKeyword: Token<"end">,
}
```

---

### AstStatLocal

```luau
type AstStatLocal = {
	read location: Span,
	read kind: "stat",
	read tag: "local",
	read localKeyword: Token<"local">,
	read variables: Punctuated<AstLocal>,
	read equals: Token<"=">?,
	read values: Punctuated<AstExpr>,
}
```

---

### AstStatLocalFunction

```luau
type AstStatLocalFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "localfunction",
	read localKeyword: Token<"local">,
	read name: AstLocal,
	read func: AstExprFunction,
}
```

---

### AstStatRepeat

```luau
type AstStatRepeat = {
	read location: Span,
	read kind: "stat",
	read tag: "repeat",
	read repeatKeyword: Token<"repeat">,
	read body: AstStatBlock,
	read untilKeyword: Token<"until">,
	read condition: AstExpr,
}
```

---

### AstStatReturn

```luau
type AstStatReturn = {
	read location: Span,
	read kind: "stat",
	read tag: "return",
	read returnKeyword: Token<"return">,
	read expressions: Punctuated<AstExpr>,
}
```

---

### AstStatTypeAlias

```luau
type AstStatTypeAlias = {
	read location: Span,
	read kind: "stat",
	read tag: "typealias",
	read export: Token<"export">?,
	read typeToken: Token<"type">,
	read name: Token,
	read openGenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericPacks: Punctuated<AstGenericTypePack>?,
	read closeGenerics: Token<">">?,
	read equals: Token<"=">,
	read type: AstType,
}
```

---

### AstStatTypeFunction

```luau
type AstStatTypeFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "typefunction",
	read export: Token<"export">?,
	read type: Token<"type">,
	read name: Token,
	read body: AstExprFunction,
}
```

---

### AstStatWhile

```luau
type AstStatWhile = {
	read location: Span,
	read kind: "stat",
	read tag: "while",
	read whileKeyword: Token<"while">,
	read condition: AstExpr,
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}
```

---

### AstTableExprGeneralItem

```luau
type AstTableExprGeneralItem = {
	read location: Span,
	read kind: "general",
	read indexerOpen: Token<"[">,
	read key: AstExpr,
	read indexerClose: Token<"]">,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}
```

---

### AstTableExprItem

```luau
type AstTableExprItem = AstTableExprListItem | AstTableExprRecordItem | AstTableExprGeneralItem
```

---

### AstTableExprListItem

```luau
type AstTableExprListItem = {
	read location: Span,
	read kind: "list",
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}
```

---

### AstTableExprRecordItem

```luau
type AstTableExprRecordItem = {
	read location: Span,
	read kind: "record",
	read key: Token<string>,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}
```

---

### AstTableTypeItem

```luau
type AstTableTypeItem = AstTableTypeItemIndexer | AstTableTypeItemStringProperty | AstTableTypeItemProperty
```

---

### AstTableTypeItemIndexer

```luau
type AstTableTypeItemIndexer = {
	read kind: "indexer",
	read access: Token<"read" | "write">?,
	read indexerOpen: Token<"[">,
	read key: AstType,
	read indexerClose: Token<"]">,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}
```

---

### AstTableTypeItemProperty

```luau
type AstTableTypeItemProperty = {
	read kind: "property",
	read access: Token<"read" | "write">?,
	read key: Token,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}
```

---

### AstTableTypeItemStringProperty

```luau
type AstTableTypeItemStringProperty = {
	read kind: "stringproperty",
	read access: Token<"read" | "write">?,
	read indexerOpen: Token<"[">,
	read key: AstTypeSingletonString,
	read indexerClose: Token<"]">,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}
```

---

### AstType

```luau
type AstType = 
```

---

### AstTypeArray

```luau
type AstTypeArray = {
	read location: Span,
	read kind: "type",
	read tag: "array",
	read openBrace: Token<"{">,
	read access: Token<"read" | "write">?,
	read type: AstType,
	read closeBrace: Token<"}">,
}
```

---

### AstTypeFunction

```luau
type AstTypeFunction = {
	read location: Span,
	read kind: "type",
	read tag: "function",
	read openGenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericPacks: Punctuated<AstGenericTypePack>?,
	read closeGenerics: Token<">">?,
	read openParens: Token<"(">,
	read parameters: Punctuated<AstFunctionTypeParameter>,
	read vararg: AstTypePack?,
	read closeParens: Token<")">,
	read returnArrow: Token<"->">,
	read returnTypes: AstTypePack,
}
```

---

### AstTypeGroup

```luau
type AstTypeGroup = {
	read location: Span,
	read kind: "type",
	read tag: "group",
	read openParens: Token<"(">,
	read type: AstType,
	read closeParens: Token<")">,
}
```

---

### AstTypeIntersection

```luau
type AstTypeIntersection = {
	read location: Span,
	read kind: "type",
	read tag: "intersection",
	read leading: Token<"&">?,
	read types: Punctuated<AstType, "&">,
}
```

---

### AstTypeOptional

```luau
type AstTypeOptional = { read location: Span, read kind: "type", read tag: "optional", read token: Token<"?"> }
```

---

### AstTypePack

```luau
type AstTypePack = AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic
```

---

### AstTypePackExplicit

```luau
type AstTypePackExplicit = {
	read location: Span,
	read kind: "typepack",
	read tag: "explicit",
	read openParens: Token<"(">?,
	read types: Punctuated<AstType>,
	read tailType: AstTypePack?,
	read closeParens: Token<")">?,
}
```

---

### AstTypePackGeneric

```luau
type AstTypePackGeneric = {
	read location: Span,
	read kind: "typepack",
	read tag: "generic",
	read name: Token,
	read ellipsis: Token<"...">,
}
```

---

### AstTypePackVariadic

```luau
type AstTypePackVariadic = {
	read location: Span,
	read kind: "typepack",
	read tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	read ellipsis: Token<"...">?,
	read type: AstType,
}
```

---

### AstTypeReference

```luau
type AstTypeReference = {
	read location: Span,
	read kind: "type",
	read tag: "reference",
	read prefix: Token<string>?,
	read prefixPoint: Token<".">?,
	read name: Token<string>,
	read openParameters: Token<"<">?,
	read parameters: Punctuated<AstType | AstTypePack>?,
	read closeParameters: Token<">">?,
}
```

---

### AstTypeSingletonBool

```luau
type AstTypeSingletonBool = {
	read location: Span,
	read kind: "type",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}
```

---

### AstTypeSingletonString

```luau
type AstTypeSingletonString = {
	read location: Span,
	read kind: "type",
	read tag: "string",
	read quoteStyle: "single" | "double",
	read token: Token<string>,
}
```

---

### AstTypeTable

```luau
type AstTypeTable = {
	read location: Span,
	read kind: "type",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableTypeItem },
	read closeBrace: Token<"}">,
}
```

---

### AstTypeTypeof

```luau
type AstTypeTypeof = {
	read location: Span,
	read kind: "type",
	read tag: "typeof",
	read typeof: Token<"typeof">,
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}
```

---

### AstTypeUnion

```luau
type AstTypeUnion = {
	read location: Span,
	read kind: "type",
	read tag: "union",
	read leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	read types: Punctuated<AstType, "|">,
}
```

---

### Bytecode

```luau
type Bytecode = { bytecode: string }
```

---

### Eof

```luau
type Eof = Token<""> & { read tag: "eof" }
```

---

### MultiLineComment

```luau
type MultiLineComment = {
	read tag: "blockcomment",
	read location: Span,
	read text: string,
	-- TODO: depth: number,
}
```

---

### ParseResult

```luau
type ParseResult = {
	read root: AstStatBlock,
	read eof: Eof,
	read lines: number,
	read lineOffsets: { number },
}
```

---

### SingleLineComment

```luau
type SingleLineComment = {
	read tag: "comment",
	read location: Span,
	read text: string,
}
```

---

### Span

```luau
type Span = setmetatable<SpanData, SpanMT>
```

---

### Trivia

```luau
type Trivia = Whitespace | SingleLineComment | MultiLineComment
```

---

### Type

```luau
type Type = {
	tag: "nil"
		| "unknown"
		| "never"
		| "any"
		| "boolean"
		| "number"
		| "string"
		| "buffer"
		| "thread"
		| "singleton"
		| "negation"
		| "union"
		| "intersection"
		| "table"
		| "function"
		| "extern"
		| "generic",

	-- for singleton type
	value: string | boolean | nil,

	-- for negation type
	inner: Type,

	-- for union and intersection types
	components: { Type },

	-- for table type
	properties: { [string]: { read: Type?, write: Type? } },
	indexer: { index: Type }?, -- TODO: add readresult and writeresult
	-- TODO: readindexer: { index: type, result: type } }?,
```

---

### TypePack

```luau
type TypePack = {
	tag: "typepack" | "variadic" | "generic",
	head: { Type }?,
	tail: TypePack?,

	-- for variadic type packs
	type: Type,
	hidden: boolean,

	-- for generic type packs
	name: string,
	ispack: boolean,
}
```

---

### Whitespace

```luau
type Whitespace = {
	read tag: "whitespace",
	read location: Span,
	read text: string,
}
```

---

## Functions and Properties

### luau.compile

```luau
(source: string) -> Bytecode
```

---

### luau.load

```luau
(bytecode: Bytecode, chunkname: string, env: { [any]: any }?) -> (...any) -> ...any
```

---

### luau.parse

```luau
(source: string) -> ParseResult
```

---

### luau.parseExpr

```luau
(source: string) -> AstExpr
```

---

### luau.resolveModule

```luau
(path: string, fromchunkname: string) -> string
```

---

### luau.span.create

```luau
(tbl: { beginLine: number, beginColumn: number, endLine: number, endColumn: number }) -> Span
```

---

### luau.typeofModule

```luau
(modulepath: string) -> TypePack?
```

---
