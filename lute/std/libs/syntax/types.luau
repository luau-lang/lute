local luau = require("@lute/luau")

export type Position = luau.Position
export type Location = luau.Location

export type Whitespace = luau.Whitespace
export type SingleLineComment = luau.SingleLineComment
export type MultiLineComment = luau.MultiLineComment

export type Trivia = luau.Trivia

export type Token<Kind = string> = luau.Token<Kind>

export type Eof = luau.Eof

export type Pair<T, Separator> = luau.Pair<T, Separator>
export type Punctuated<T, Separator = ","> = luau.Punctuated<T, Separator>

export type AstLocal = luau.AstLocal

export type AstExprGroup = luau.AstExprGroup

export type AstExprConstantNil = luau.AstExprConstantNil

export type AstExprConstantBool = luau.AstExprConstantBool

export type AstExprConstantNumber = luau.AstExprConstantNumber

export type AstExprConstantString = luau.AstExprConstantString

export type AstExprLocal = luau.AstExprLocal

export type AstExprGlobal = luau.AstExprGlobal

export type AstExprVarargs = luau.AstExprVarargs

export type AstExprCall = luau.AstExprCall

export type AstExprIndexName = luau.AstExprIndexName

export type AstExprIndexExpr = luau.AstExprIndexExpr

export type AstFunctionBody = luau.AstFunctionBody

export type AstExprAnonymousFunction = luau.AstExprAnonymousFunction

export type AstExprTableItemList = luau.AstExprTableItemList

export type AstExprTableItemRecord = luau.AstExprTableItemRecord

export type AstExprTableItemGeneral = luau.AstExprTableItemGeneral

export type AstExprTableItem = luau.AstExprTableItem

export type AstExprTable = luau.AstExprTable

export type AstExprUnary = luau.AstExprUnary

export type AstExprBinary = luau.AstExprBinary

export type AstExprInterpString = luau.AstExprInterpString

export type AstExprTypeAssertion = luau.AstExprTypeAssertion

export type AstElseIfExpr = luau.AstElseIfExpr

export type AstExprIfElse = luau.AstExprIfElse

export type AstExpr = luau.AstExpr

export type AstStatBlock = luau.AstStatBlock

export type AstElseIfStat = luau.AstElseIfStat

export type AstStatIf = luau.AstStatIf

export type AstStatWhile = luau.AstStatWhile

export type AstStatRepeat = luau.AstStatRepeat

export type AstStatBreak = luau.AstStatBreak

export type AstStatContinue = luau.AstStatContinue

export type AstStatReturn = luau.AstStatReturn

export type AstStatExpr = luau.AstStatExpr

export type AstStatLocal = luau.AstStatLocal

export type AstStatFor = luau.AstStatFor

export type AstStatForIn = luau.AstStatForIn

export type AstStatAssign = luau.AstStatAssign

export type AstStatCompoundAssign = luau.AstStatCompoundAssign

export type AstAttribute = luau.AstAttribute

export type AstStatFunction = luau.AstStatFunction

export type AstStatLocalFunction = luau.AstStatLocalFunction

export type AstStatTypeAlias = luau.AstStatTypeAlias

export type AstStatTypeFunction = luau.AstStatTypeFunction

export type AstStat = luau.AstStat

export type AstGenericType = luau.AstGenericType

export type AstGenericTypePack = luau.AstGenericTypePack

export type AstTypeReference = luau.AstTypeReference

export type AstTypeSingletonBool = luau.AstTypeSingletonBool

export type AstTypeSingletonString = luau.AstTypeSingletonString

export type AstTypeTypeof = luau.AstTypeTypeof

export type AstTypeGroup = luau.AstTypeGroup

export type AstTypeOptional = luau.AstTypeOptional

export type AstTypeUnion = luau.AstTypeUnion

export type AstTypeIntersection = luau.AstTypeIntersection

export type AstTypeArray = luau.AstTypeArray

export type AstTypeTableItemIndexer = luau.AstTypeTableItemIndexer

export type AstTypeTableItemStringProperty = luau.AstTypeTableItemStringProperty

export type AstTypeTableItemProperty = luau.AstTypeTableItemProperty

export type AstTypeTableItem = luau.AstTypeTableItem

export type AstTypeTable = luau.AstTypeTable

export type AstTypeFunctionParameter = luau.AstTypeFunctionParameter

export type AstTypeFunction = luau.AstTypeFunction

export type AstType = luau.AstType

export type AstTypePackExplicit = luau.AstTypePackExplicit

export type AstTypePackGeneric = luau.AstTypePackGeneric

export type AstTypePackVariadic = luau.AstTypePackVariadic

export type AstTypePack = luau.AstTypePack

export type AstNode = luau.AstNode

export type ParseResult = luau.ParseResult

export type replacement = string | AstNode
export type replacements = { [AstNode]: replacement, print: (self: replacements) -> string, __root: AstNode, __eof: Eof? }

return {}
