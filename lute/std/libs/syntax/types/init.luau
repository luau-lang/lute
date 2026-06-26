local cst = require("@lute/syntax/cst")
local luau = require("@lute/luau")

export type Span = cst.Span

export type Whitespace = cst.Whitespace
export type SingleLineComment = cst.SingleLineComment
export type MultiLineComment = cst.MultiLineComment

export type Trivia = cst.Trivia

export type CstToken<Kind = string> = cst.CstToken<Kind>

export type CstEof = cst.CstEof

export type CstPunctuated<T, Separator = ","> = cst.CstPunctuated<T, Separator>

export type CstLocal = cst.CstLocal

export type CstExprGroup = cst.CstExprGroup

export type CstExprConstantNil = cst.CstExprConstantNil

export type CstExprConstantBool = cst.CstExprConstantBool

export type CstExprConstantNumber = cst.CstExprConstantNumber

export type CstExprConstantInteger = cst.CstExprConstantInteger

export type CstExprConstantString = cst.CstExprConstantString

export type CstExprLocal = cst.CstExprLocal

export type CstExprGlobal = cst.CstExprGlobal

export type CstExprVarargs = cst.CstExprVarargs

export type CstExprCall = cst.CstExprCall

export type CstExprInstantiate = cst.CstExprInstantiate

export type CstExprIndexName = cst.CstExprIndexName

export type CstExprIndexExpr = cst.CstExprIndexExpr

export type CstExprFunction = cst.CstExprFunction

export type CstTableExprListItem = cst.CstTableExprListItem

export type CstTableExprRecordItem = cst.CstTableExprRecordItem

export type CstTableExprGeneralItem = cst.CstTableExprGeneralItem

export type CstTableExprItem = cst.CstTableExprItem

export type CstExprTable = cst.CstExprTable

export type CstExprUnary = cst.CstExprUnary

export type CstExprBinary = cst.CstExprBinary

export type CstExprInterpString = cst.CstExprInterpString

export type CstExprTypeAssertion = cst.CstExprTypeAssertion

export type CstElseIfExpr = cst.CstElseIfExpr

export type CstExprIfElse = cst.CstExprIfElse

export type CstExpr = cst.CstExpr

export type CstStatBlock = cst.CstStatBlock

export type CstStatDo = cst.CstStatDo

export type CstElseIfStat = cst.CstElseIfStat

export type CstStatIf = cst.CstStatIf

export type CstStatWhile = cst.CstStatWhile

export type CstStatRepeat = cst.CstStatRepeat

export type CstStatBreak = cst.CstStatBreak

export type CstStatContinue = cst.CstStatContinue

export type CstStatReturn = cst.CstStatReturn

export type CstStatExpr = cst.CstStatExpr

export type CstStatLocal = cst.CstStatLocal

export type CstStatConst = cst.CstStatConst

export type CstStatFor = cst.CstStatFor

export type CstStatForIn = cst.CstStatForIn

export type CstStatAssign = cst.CstStatAssign

export type CstStatCompoundAssign = cst.CstStatCompoundAssign

export type CstAttributeSimple = cst.CstAttributeSimple

export type CstAttributeParametrized = cst.CstAttributeParametrized

export type CstAttribute = cst.CstAttribute

export type CstStatFunction = cst.CstStatFunction

export type CstStatLocalFunction = cst.CstStatLocalFunction

export type CstStatTypeAlias = cst.CstStatTypeAlias

export type CstStatTypeFunction = cst.CstStatTypeFunction

export type CstStat = cst.CstStat

export type CstGenericType = cst.CstGenericType

export type CstGenericTypePack = cst.CstGenericTypePack

export type CstTypeReference = cst.CstTypeReference

export type CstTypeSingletonBool = cst.CstTypeSingletonBool

export type CstTypeSingletonString = cst.CstTypeSingletonString

export type CstTypeTypeof = cst.CstTypeTypeof

export type CstTypeGroup = cst.CstTypeGroup

export type CstTypeOptional = cst.CstTypeOptional

export type CstTypeUnion = cst.CstTypeUnion

export type CstTypeIntersection = cst.CstTypeIntersection

export type CstTypeArray = cst.CstTypeArray

export type CstTableTypeItemIndexer = cst.CstTableTypeItemIndexer

export type CstTableTypeItemStringProperty = cst.CstTableTypeItemStringProperty

export type CstTableTypeItemProperty = cst.CstTableTypeItemProperty

export type CstTableTypeItem = cst.CstTableTypeItem

export type CstTypeTable = cst.CstTypeTable

export type CstFunctionTypeParameter = cst.CstFunctionTypeParameter

export type CstTypeFunction = cst.CstTypeFunction

export type CstType = cst.CstType

export type CstTypePackExplicit = cst.CstTypePackExplicit

export type CstTypePackGeneric = cst.CstTypePackGeneric

export type CstTypePackVariadic = cst.CstTypePackVariadic

export type CstTypePack = cst.CstTypePack

export type CstNode = cst.CstNode

export type CstParseResult = cst.CstParseResult

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
