local parser = require("@self/parser")
local types = require("@self/types")

local luau = require("@lute/luau")

export type Span = types.Span

local span = {
	--- Creates a `Span` from begin/end line and column values.
	create = luau.span.create,
}

--- Returns `true` if `haystack` fully contains `needle`.
function span.subsumes(haystack: Span, needle: Span): boolean
	return (
		if haystack.beginLine == needle.beginLine
			then haystack.beginColumn <= needle.beginColumn
			else haystack.beginLine < needle.beginLine
	)
		and (
			if haystack.endLine == needle.endLine
				then haystack.endColumn >= needle.endColumn
				else haystack.endLine > needle.endLine
		)
end

export type Whitespace = types.Whitespace
export type SingleLineComment = types.SingleLineComment
export type MultiLineComment = types.MultiLineComment

export type Trivia = types.Trivia

export type CstToken<Kind = string> = types.CstToken<Kind>

export type CstEof = types.CstEof

export type Pair<T, Separator> = types.Pair<T, Separator>
export type Punctuated<T, Separator = ","> = types.Punctuated<T, Separator>

export type CstLocal = types.CstLocal

export type CstExprGroup = types.CstExprGroup

export type CstExprConstantNil = types.CstExprConstantNil

export type CstExprConstantBool = types.CstExprConstantBool

export type CstExprConstantNumber = types.CstExprConstantNumber

export type CstExprConstantInteger = types.CstExprConstantInteger

export type CstExprConstantString = types.CstExprConstantString

export type CstExprLocal = types.CstExprLocal

export type CstExprGlobal = types.CstExprGlobal

export type CstExprVarargs = types.CstExprVarargs

export type CstExprCall = types.CstExprCall

export type CstExprInstantiate = types.CstExprInstantiate

export type CstExprIndexName = types.CstExprIndexName

export type CstExprIndexExpr = types.CstExprIndexExpr

export type CstExprFunction = types.CstExprFunction

export type CstTableExprListItem = types.CstTableExprListItem

export type CstTableExprRecordItem = types.CstTableExprRecordItem

export type CstTableExprGeneralItem = types.CstTableExprGeneralItem

export type CstTableExprItem = types.CstTableExprItem

export type CstExprTable = types.CstExprTable

export type CstExprUnary = types.CstExprUnary

export type CstExprBinary = types.CstExprBinary

export type CstExprInterpString = types.CstExprInterpString

export type CstExprTypeAssertion = types.CstExprTypeAssertion

export type CstElseIfExpr = types.CstElseIfExpr

export type CstExprIfElse = types.CstExprIfElse

export type CstExpr = types.CstExpr

export type CstStatBlock = types.CstStatBlock

export type CstStatDo = types.CstStatDo

export type CstElseIfStat = types.CstElseIfStat

export type CstStatIf = types.CstStatIf

export type CstStatWhile = types.CstStatWhile

export type CstStatRepeat = types.CstStatRepeat

export type CstStatBreak = types.CstStatBreak

export type CstStatContinue = types.CstStatContinue

export type CstStatReturn = types.CstStatReturn

export type CstStatExpr = types.CstStatExpr

export type CstStatLocal = types.CstStatLocal

export type CstStatFor = types.CstStatFor

export type CstStatForIn = types.CstStatForIn

export type CstStatAssign = types.CstStatAssign

export type CstStatCompoundAssign = types.CstStatCompoundAssign

export type CstAttribute = types.CstAttribute

export type CstStatFunction = types.CstStatFunction

export type CstStatLocalFunction = types.CstStatLocalFunction

export type CstStatTypeAlias = types.CstStatTypeAlias

export type CstStatTypeFunction = types.CstStatTypeFunction

export type CstStat = types.CstStat

export type CstGenericType = types.CstGenericType

export type CstGenericTypePack = types.CstGenericTypePack

export type CstTypeReference = types.CstTypeReference

export type CstTypeSingletonBool = types.CstTypeSingletonBool

export type CstTypeSingletonString = types.CstTypeSingletonString

export type CstTypeTypeof = types.CstTypeTypeof

export type CstTypeGroup = types.CstTypeGroup

export type CstTypeOptional = types.CstTypeOptional

export type CstTypeUnion = types.CstTypeUnion

export type CstTypeIntersection = types.CstTypeIntersection

export type CstTypeArray = types.CstTypeArray

export type CstTableTypeItemIndexer = types.CstTableTypeItemIndexer

export type CstTableTypeItemStringProperty = types.CstTableTypeItemStringProperty

export type CstTableTypeItemProperty = types.CstTableTypeItemProperty

export type CstTableTypeItem = types.CstTableTypeItem

export type CstTypeTable = types.CstTypeTable

export type CstFunctionTypeParameter = types.CstFunctionTypeParameter

export type CstTypeFunction = types.CstTypeFunction

export type CstType = types.CstType

export type CstTypePackExplicit = types.CstTypePackExplicit

export type CstTypePackGeneric = types.CstTypePackGeneric

export type CstTypePackVariadic = types.CstTypePackVariadic

export type CstTypePack = types.CstTypePack

export type CstNode = types.CstNode

export type CstParseResult = types.CstParseResult

return table.freeze({
	parseBlock = parser.parseBlock,
	parseExpr = parser.parseExpr,
	parse = parser.parse,
	span = table.freeze(span),
})
