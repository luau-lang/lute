local parser = require("@self/parser")
local types = require("@self/types")

local luau = require("@lute/luau")

export type span = types.span

local span = {
	create = luau.span.create,
}

function span.subsumes(haystack: span, needle: span): boolean
	return (
		if haystack.beginline == needle.beginline
			then haystack.begincolumn <= needle.begincolumn
			else haystack.beginline < needle.beginline
	)
		and (
			if haystack.endline == needle.endline
				then haystack.endcolumn >= needle.endcolumn
				else haystack.endline > needle.endline
		)
end

export type Whitespace = types.Whitespace
export type SingleLineComment = types.SingleLineComment
export type MultiLineComment = types.MultiLineComment

export type Trivia = types.Trivia

export type Token<Kind = string> = types.Token<Kind>

export type Eof = types.Eof

export type Pair<T, Separator> = types.Pair<T, Separator>
export type Punctuated<T, Separator = ","> = types.Punctuated<T, Separator>

export type AstLocal = types.AstLocal

export type AstExprGroup = types.AstExprGroup

export type AstExprConstantNil = types.AstExprConstantNil

export type AstExprConstantBool = types.AstExprConstantBool

export type AstExprConstantNumber = types.AstExprConstantNumber

export type AstExprConstantString = types.AstExprConstantString

export type AstExprLocal = types.AstExprLocal

export type AstExprGlobal = types.AstExprGlobal

export type AstExprVarargs = types.AstExprVarargs

export type AstExprCall = types.AstExprCall

export type AstExprIndexName = types.AstExprIndexName

export type AstExprIndexExpr = types.AstExprIndexExpr

export type AstExprFunction = types.AstExprFunction

export type AstExprTableItemList = types.AstExprTableItemList

export type AstExprTableItemRecord = types.AstExprTableItemRecord

export type AstExprTableItemGeneral = types.AstExprTableItemGeneral

export type AstExprTableItem = types.AstExprTableItem

export type AstExprTable = types.AstExprTable

export type AstExprUnary = types.AstExprUnary

export type AstExprBinary = types.AstExprBinary

export type AstExprInterpString = types.AstExprInterpString

export type AstExprTypeAssertion = types.AstExprTypeAssertion

export type AstElseIfExpr = types.AstElseIfExpr

export type AstExprIfElse = types.AstExprIfElse

export type AstExpr = types.AstExpr

export type AstStatBlock = types.AstStatBlock

export type AstStatDo = types.AstStatDo

export type AstElseIfStat = types.AstElseIfStat

export type AstStatIf = types.AstStatIf

export type AstStatWhile = types.AstStatWhile

export type AstStatRepeat = types.AstStatRepeat

export type AstStatBreak = types.AstStatBreak

export type AstStatContinue = types.AstStatContinue

export type AstStatReturn = types.AstStatReturn

export type AstStatExpr = types.AstStatExpr

export type AstStatLocal = types.AstStatLocal

export type AstStatFor = types.AstStatFor

export type AstStatForIn = types.AstStatForIn

export type AstStatAssign = types.AstStatAssign

export type AstStatCompoundAssign = types.AstStatCompoundAssign

export type AstAttribute = types.AstAttribute

export type AstStatFunction = types.AstStatFunction

export type AstStatLocalFunction = types.AstStatLocalFunction

export type AstStatTypeAlias = types.AstStatTypeAlias

export type AstStatTypeFunction = types.AstStatTypeFunction

export type AstStat = types.AstStat

export type AstGenericType = types.AstGenericType

export type AstGenericTypePack = types.AstGenericTypePack

export type AstTypeReference = types.AstTypeReference

export type AstTypeSingletonBool = types.AstTypeSingletonBool

export type AstTypeSingletonString = types.AstTypeSingletonString

export type AstTypeTypeof = types.AstTypeTypeof

export type AstTypeGroup = types.AstTypeGroup

export type AstTypeOptional = types.AstTypeOptional

export type AstTypeUnion = types.AstTypeUnion

export type AstTypeIntersection = types.AstTypeIntersection

export type AstTypeArray = types.AstTypeArray

export type AstTypeTableItemIndexer = types.AstTypeTableItemIndexer

export type AstTypeTableItemStringProperty = types.AstTypeTableItemStringProperty

export type AstTypeTableItemProperty = types.AstTypeTableItemProperty

export type AstTypeTableItem = types.AstTypeTableItem

export type AstTypeTable = types.AstTypeTable

export type AstTypeFunctionParameter = types.AstTypeFunctionParameter

export type AstTypeFunction = types.AstTypeFunction

export type AstType = types.AstType

export type AstTypePackExplicit = types.AstTypePackExplicit

export type AstTypePackGeneric = types.AstTypePackGeneric

export type AstTypePackVariadic = types.AstTypePackVariadic

export type AstTypePack = types.AstTypePack

export type AstNode = types.AstNode

export type ParseResult = types.ParseResult

return table.freeze({
	parseblock = parser.parseblock,
	parseexpr = parser.parseexpr,
	parse = parser.parse,
	span = table.freeze(span),
})
