local luau = require("@lute/luau")

export type Span = luau.Span

export type Whitespace = luau.Whitespace
export type SingleLineComment = luau.SingleLineComment
export type MultiLineComment = luau.MultiLineComment

export type Trivia = luau.Trivia

export type CstToken<Kind = string> = luau.CstToken<Kind>

export type CstEof = luau.CstEof

export type Punctuated<T, Separator = ","> = luau.Punctuated<T, Separator>

export type CstLocal = luau.CstLocal

export type CstExprGroup = luau.CstExprGroup

export type CstExprConstantNil = luau.CstExprConstantNil

export type CstExprConstantBool = luau.CstExprConstantBool

export type CstExprConstantNumber = luau.CstExprConstantNumber

export type CstExprConstantInteger = luau.CstExprConstantInteger

export type CstExprConstantString = luau.CstExprConstantString

export type CstExprLocal = luau.CstExprLocal

export type CstExprGlobal = luau.CstExprGlobal

export type CstExprVarargs = luau.CstExprVarargs

export type CstExprCall = luau.CstExprCall

export type CstExprInstantiate = luau.CstExprInstantiate

export type CstExprIndexName = luau.CstExprIndexName

export type CstExprIndexExpr = luau.CstExprIndexExpr

export type CstExprFunction = luau.CstExprFunction

export type CstTableExprListItem = luau.CstTableExprListItem

export type CstTableExprRecordItem = luau.CstTableExprRecordItem

export type CstTableExprGeneralItem = luau.CstTableExprGeneralItem

export type CstTableExprItem = luau.CstTableExprItem

export type CstExprTable = luau.CstExprTable

export type CstExprUnary = luau.CstExprUnary

export type CstExprBinary = luau.CstExprBinary

export type CstExprInterpString = luau.CstExprInterpString

export type CstExprTypeAssertion = luau.CstExprTypeAssertion

export type CstElseIfExpr = luau.CstElseIfExpr

export type CstExprIfElse = luau.CstExprIfElse

export type CstExpr = luau.CstExpr

export type CstStatBlock = luau.CstStatBlock

export type CstStatDo = luau.CstStatDo

export type CstElseIfStat = luau.CstElseIfStat

export type CstStatIf = luau.CstStatIf

export type CstStatWhile = luau.CstStatWhile

export type CstStatRepeat = luau.CstStatRepeat

export type CstStatBreak = luau.CstStatBreak

export type CstStatContinue = luau.CstStatContinue

export type CstStatReturn = luau.CstStatReturn

export type CstStatExpr = luau.CstStatExpr

export type CstStatLocal = luau.CstStatLocal

export type CstStatConst = luau.CstStatConst

export type CstStatFor = luau.CstStatFor

export type CstStatForIn = luau.CstStatForIn

export type CstStatAssign = luau.CstStatAssign

export type CstStatCompoundAssign = luau.CstStatCompoundAssign

export type CstAttribute = luau.CstAttribute

export type CstStatFunction = luau.CstStatFunction

export type CstStatLocalFunction = luau.CstStatLocalFunction

export type CstStatTypeAlias = luau.CstStatTypeAlias

export type CstStatTypeFunction = luau.CstStatTypeFunction

export type CstStat = luau.CstStat

export type CstGenericType = luau.CstGenericType

export type CstGenericTypePack = luau.CstGenericTypePack

export type CstTypeReference = luau.CstTypeReference

export type CstTypeSingletonBool = luau.CstTypeSingletonBool

export type CstTypeSingletonString = luau.CstTypeSingletonString

export type CstTypeTypeof = luau.CstTypeTypeof

export type CstTypeGroup = luau.CstTypeGroup

export type CstTypeOptional = luau.CstTypeOptional

export type CstTypeUnion = luau.CstTypeUnion

export type CstTypeIntersection = luau.CstTypeIntersection

export type CstTypeArray = luau.CstTypeArray

export type CstTableTypeItemIndexer = luau.CstTableTypeItemIndexer

export type CstTableTypeItemStringProperty = luau.CstTableTypeItemStringProperty

export type CstTableTypeItemProperty = luau.CstTableTypeItemProperty

export type CstTableTypeItem = luau.CstTableTypeItem

export type CstTypeTable = luau.CstTypeTable

export type CstFunctionTypeParameter = luau.CstFunctionTypeParameter

export type CstTypeFunction = luau.CstTypeFunction

export type CstType = luau.CstType

export type CstTypePackExplicit = luau.CstTypePackExplicit

export type CstTypePackGeneric = luau.CstTypePackGeneric

export type CstTypePackVariadic = luau.CstTypePackVariadic

export type CstTypePack = luau.CstTypePack

export type CstNode = luau.CstNode

export type ParseResult = luau.ParseResult

--- The type of a replacement for a CST node.
--- A replacement can be:
--- 1. A string, which will be used as the replacement text for the node, with any surrounding trivia preserved.
--- 2. An object with a `content` property containing the replacement string, and an optional `preserveTrivia` boolean property.
---    If `preserveTrivia` is true, the replaced CST node's attached trivia (whitespace and comments) will be reserialized with the replacement content.
---    If false, the trivia will be discarded. If omitted, trivia is preserved by default.
--- Note that trailing trivia for a token consists of all whitespace and comments that follow it up to and including a newline.
--- Any trivia after the first seen newline is considered leading trivia for the next token.
export type Replacement = string | { content: string, preserveTrivia: boolean? }

--- A mapping of CST nodes to their replacements, used with `@std/syntax/printer` and `lute transform` to specify how CSTs should be mutated.
export type Replacements = { [CstNode]: Replacement }

export type Type = luau.Type

export type TypePack = luau.TypePack

return {}
