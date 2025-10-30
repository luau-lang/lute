local luteLuau = require("@lute/luau")

local fs = require("@lute/fs")
local path = require("@std/path")

local luau = {}

-- Export all types from luteLuau
export type Position = luteLuau.Position
export type Location = luteLuau.Location

export type Whitespace = luteLuau.Whitespace
export type SingleLineComment = luteLuau.SingleLineComment
export type MultiLineComment = luteLuau.MultiLineComment

export type Trivia = luteLuau.Trivia

export type Token<Kind = string> = luteLuau.Token<Kind>

export type Eof = luteLuau.Eof

export type Pair<T, Separator> = luteLuau.Pair<T, Separator>
export type Punctuated<T, Separator = ","> = luteLuau.Punctuated<T, Separator>

export type AstLocal = luteLuau.AstLocal

export type AstExprGroup = luteLuau.AstExprGroup

export type AstExprConstantNil = luteLuau.AstExprConstantNil

export type AstExprConstantBool = luteLuau.AstExprConstantBool

export type AstExprConstantNumber = luteLuau.AstExprConstantNumber

export type AstExprConstantString = luteLuau.AstExprConstantString

export type AstExprLocal = luteLuau.AstExprLocal

export type AstExprGlobal = luteLuau.AstExprGlobal

export type AstExprVarargs = luteLuau.AstExprVarargs

export type AstExprCall = luteLuau.AstExprCall

export type AstExprIndexName = luteLuau.AstExprIndexName

export type AstExprIndexExpr = luteLuau.AstExprIndexExpr

export type AstFunctionBody = luteLuau.AstFunctionBody

export type AstExprAnonymousFunction = luteLuau.AstExprAnonymousFunction

export type AstExprTableItem = luteLuau.AstExprTableItem

export type AstExprTable = luteLuau.AstExprTable

export type AstExprUnary = luteLuau.AstExprUnary

export type AstExprBinary = luteLuau.AstExprBinary

export type AstExprInterpString = luteLuau.AstExprInterpString

export type AstExprTypeAssertion = luteLuau.AstExprTypeAssertion

export type AstExprIfElseIfs = luteLuau.AstExprIfElseIfs

export type AstExprIfElse = luteLuau.AstExprIfElse

export type AstExpr = luteLuau.AstExpr

export type AstStatBlock = luteLuau.AstStatBlock

export type AstStatElseIf = luteLuau.AstStatElseIf

export type AstStatIf = luteLuau.AstStatIf

export type AstStatWhile = luteLuau.AstStatWhile

export type AstStatRepeat = luteLuau.AstStatRepeat

export type AstStatBreak = luteLuau.AstStatBreak

export type AstStatContinue = luteLuau.AstStatContinue

export type AstStatReturn = luteLuau.AstStatReturn

export type AstStatExpr = luteLuau.AstStatExpr

export type AstStatLocal = luteLuau.AstStatLocal

export type AstStatFor = luteLuau.AstStatFor

export type AstStatForIn = luteLuau.AstStatForIn

export type AstStatAssign = luteLuau.AstStatAssign

export type AstStatCompoundAssign = luteLuau.AstStatCompoundAssign

export type AstAttribute = luteLuau.AstAttribute

export type AstStatFunction = luteLuau.AstStatFunction

export type AstStatLocalFunction = luteLuau.AstStatLocalFunction

export type AstStatTypeAlias = luteLuau.AstStatTypeAlias

export type AstStatTypeFunction = luteLuau.AstStatTypeFunction

export type AstStat = luteLuau.AstStat

export type AstGenericType = luteLuau.AstGenericType

export type AstGenericTypePack = luteLuau.AstGenericTypePack

export type AstTypeReference = luteLuau.AstTypeReference

export type AstTypeSingletonBool = luteLuau.AstTypeSingletonBool

export type AstTypeSingletonString = luteLuau.AstTypeSingletonString

export type AstTypeTypeof = luteLuau.AstTypeTypeof

export type AstTypeGroup = luteLuau.AstTypeGroup

export type AstTypeOptional = luteLuau.AstTypeOptional

export type AstTypeUnion = luteLuau.AstTypeUnion

export type AstTypeIntersection = luteLuau.AstTypeIntersection

export type AstTypeArray = luteLuau.AstTypeArray

export type AstTypeTableItem = luteLuau.AstTypeTableItem

export type AstTypeTable = luteLuau.AstTypeTable

export type AstTypeFunctionParameter = luteLuau.AstTypeFunctionParameter

export type AstTypeFunction = luteLuau.AstTypeFunction

export type AstType = luteLuau.AstType

export type AstTypePackExplicit = luteLuau.AstTypePackExplicit

export type AstTypePackGeneric = luteLuau.AstTypePackGeneric

export type AstTypePackVariadic = luteLuau.AstTypePackVariadic

export type AstTypePack = luteLuau.AstTypePack

export type AstNode = luteLuau.AstNode

export type ParseResult = luteLuau.ParseResult

export type Bytecode = luteLuau.Bytecode

function luau.parse(source: string): ParseResult
	return luteLuau.parse(source)
end

function luau.parseexpr(source: string): AstExpr
	return luteLuau.parseexpr(source)
end

function luau.compile(source: string): Bytecode
	return luteLuau.compile(source)
end

function luau.load(bytecode: Bytecode, chunkname: string?, env: { [any]: any }?): (...any) -> ...any
	return luteLuau.load(bytecode, if chunkname ~= nil then `@{chunkname}` else "=luau.load", env)
end

function luau.loadbypath(requirePath: path.pathlike): any
	local requirePathStr = if typeof(requirePath) == "string" then requirePath else path.format(requirePath)

	local migrationHandle = fs.open(requirePathStr, "r")

	local migrationBytecode = luau.compile(fs.read(migrationHandle))

	fs.close(migrationHandle)

	return luau.load(migrationBytecode, requirePathStr)()
end

return luau
