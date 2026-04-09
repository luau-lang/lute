-- lute-lint-global-ignore(unused_variable)
local luau = {}

type SpanData = {
	read beginLine: number,
	read beginColumn: number,
	read endLine: number,
	read endColumn: number,
}
type SpanMT = {
	read __lt: (a: SpanData, b: SpanData) -> boolean,
}
export type Span = setmetatable<SpanData, SpanMT>

luau.span = {}

function luau.span.create(tbl: { beginLine: number, beginColumn: number, endLine: number, endColumn: number }): Span
	error("not implemented")
end

export type Whitespace = {
	read tag: "whitespace",
	read location: Span,
	read text: string,
}

export type SingleLineComment = {
	read tag: "comment",
	read location: Span,
	read text: string,
}

export type MultiLineComment = {
	read tag: "blockcomment",
	read location: Span,
	read text: string,
	-- TODO: depth: number,
}

export type Trivia = Whitespace | SingleLineComment | MultiLineComment

export type Token<Kind = string> = {
	read leadingTrivia: { Trivia },
	read location: Span,
	read text: Kind,
	read trailingTrivia: { Trivia },
	read kind: "token",
}

export type Eof = Token<""> & { read tag: "eof" }

export type Pair<T, Separator> = { read node: T, read separator: Token<Separator>? }
export type Punctuated<T, Separator = ","> = { Pair<T, Separator> }

export type AstLocal = {
	read location: Span,
	read kind: "local",
	read name: Token<string>,
	read colon: Token<":">?,
	read annotation: AstType?,
	read shadows: AstLocal?,
}

export type AstExprGroup = {
	read location: Span,
	read kind: "expr",
	read tag: "group",
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}

export type AstExprConstantNil = {
	read location: Span,
	read kind: "expr",
	read tag: "nil",
	read token: Token<"nil">,
}

export type AstExprConstantBool = {
	read location: Span,
	read kind: "expr",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}

export type AstExprConstantNumber = {
	read location: Span,
	read kind: "expr",
	read tag: "number",
	read value: number,
	read token: Token<string>,
}

export type AstExprConstantString = {
	read location: Span,
	read kind: "expr",
	read tag: "string",
	read quoteStyle: "single" | "double" | "block" | "interp",
	read blockDepth: number,
	read token: Token<string>,
}

export type AstExprLocal = {
	read location: Span,
	read kind: "expr",
	read tag: "local",
	read token: Token<string>,
	read ["local"]: AstLocal,
	read upvalue: boolean,
}

export type AstExprGlobal = { read location: Span, read kind: "expr", read tag: "global", read name: Token }

export type AstExprVarargs = {
	read location: Span,
	read kind: "expr",
	read tag: "vararg",
	read token: Token<"...">,
}

export type AstExprCall = {
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

export type AstExprInstantiate = {
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

export type AstExprIndexName = {
	read location: Span,
	read kind: "expr",
	read tag: "indexname",
	read expression: AstExpr,
	read accessor: Token<"." | ":">,
	read index: Token<string>,
	read indexLocation: Span,
}

export type AstExprIndexExpr = {
	read location: Span,
	read kind: "expr",
	read tag: "index",
	read expression: AstExpr,
	read openBrackets: Token<"[">,
	read index: AstExpr,
	read closeBrackets: Token<"]">,
}

export type AstExprFunction = {
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

-- helper types for items contained in an AstExprTable, not actually AstExprs themselves
export type AstTableExprListItem = {
	read location: Span,
	read kind: "list",
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}

export type AstTableExprRecordItem = {
	read location: Span,
	read kind: "record",
	read key: Token<string>,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}

export type AstTableExprGeneralItem = {
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

export type AstTableExprItem = AstTableExprListItem | AstTableExprRecordItem | AstTableExprGeneralItem

export type AstExprTable = {
	read location: Span,
	read kind: "expr",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableExprItem },
	read closeBrace: Token<"}">,
}

export type AstExprUnary = {
	read location: Span,
	read kind: "expr",
	read tag: "unary",
	read operator: Token<"not" | "-" | "#">,
	read operand: AstExpr,
}

export type AstExprBinary = {
	read location: Span,
	read kind: "expr",
	read tag: "binary",
	read lhsOperand: AstExpr,
	read operator: Token,
	read rhsOperand: AstExpr,
}

export type AstExprInterpString = {
	read location: Span,
	read kind: "expr",
	read tag: "interpolatedstring",
	read strings: { Token<string> },
	read expressions: { AstExpr },
}

export type AstExprTypeAssertion = {
	read location: Span,
	read kind: "expr",
	read tag: "cast",
	read operand: AstExpr,
	read operator: Token<"::">,
	read annotation: AstType,
}

-- helper type for elseif clauses of an if-else expression, not actually an AstExpr itself
export type AstElseIfExpr = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenExpr: AstExpr,
}

export type AstExprIfElse = {
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

export type AstExpr =
	| AstExprGroup
	| AstExprConstantNil
	| AstExprConstantBool
	| AstExprConstantNumber
	| AstExprConstantString
	| AstExprLocal
	| AstExprGlobal
	| AstExprVarargs
	| AstExprCall
	| AstExprInstantiate
	| AstExprIndexName
	| AstExprIndexExpr
	| AstExprFunction
	| AstExprTable
	| AstExprUnary
	| AstExprBinary
	| AstExprInterpString
	| AstExprTypeAssertion
	| AstExprIfElse

export type AstStatBlock = {
	read location: Span,
	read kind: "stat",
	read tag: "block",
	read statements: { AstStat },
}

export type AstStatDo = {
	read location: Span,
	read kind: "stat",
	read tag: "do",
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

export type AstElseIfStat = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenBlock: AstStatBlock,
}

export type AstStatIf = {
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

export type AstStatWhile = {
	read location: Span,
	read kind: "stat",
	read tag: "while",
	read whileKeyword: Token<"while">,
	read condition: AstExpr,
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

export type AstStatRepeat = {
	read location: Span,
	read kind: "stat",
	read tag: "repeat",
	read repeatKeyword: Token<"repeat">,
	read body: AstStatBlock,
	read untilKeyword: Token<"until">,
	read condition: AstExpr,
}

export type AstStatBreak = { read location: Span, read kind: "stat", read tag: "break", read token: Token<"break"> }

export type AstStatContinue = {
	read location: Span,
	read kind: "stat",
	read tag: "continue",
	read token: Token<"continue">,
}

export type AstStatReturn = {
	read location: Span,
	read kind: "stat",
	read tag: "return",
	read returnKeyword: Token<"return">,
	read expressions: Punctuated<AstExpr>,
}

export type AstStatExpr = {
	read location: Span,
	read kind: "stat",
	read tag: "expression",
	read expression: AstExpr,
}

export type AstStatLocal = {
	read location: Span,
	read kind: "stat",
	read tag: "local",
	read localKeyword: Token<"local">,
	read variables: Punctuated<AstLocal>,
	read equals: Token<"=">?,
	read values: Punctuated<AstExpr>,
}

export type AstStatFor = {
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

export type AstStatForIn = {
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

export type AstStatAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "assign",
	read variables: Punctuated<AstExpr>,
	read equals: Token<"=">,
	read values: Punctuated<AstExpr>,
}

export type AstStatCompoundAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "compoundassign",
	read variable: AstExpr,
	read operand: Token, -- TODO: Enforce token type
	read value: AstExpr,
}

export type AstAttribute = {
	read location: Span,
	read kind: "attribute",
	read token: Token<"@checked" | "@native" | "@deprecated">,
}

export type AstStatFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "function",
	read name: AstExpr,
	read func: AstExprFunction,
}

export type AstStatLocalFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "localfunction",
	read localKeyword: Token<"local">,
	read name: AstLocal,
	read func: AstExprFunction,
}

export type AstStatTypeAlias = {
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

-- A type function
export type AstStatTypeFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "typefunction",
	read export: Token<"export">?,
	read type: Token<"type">,
	read name: Token,
	read body: AstExprFunction,
}

export type AstStat =
	| AstStatBlock
	| AstStatDo
	| AstStatIf
	| AstStatWhile
	| AstStatRepeat
	| AstStatBreak
	| AstStatContinue
	| AstStatReturn
	| AstStatExpr
	| AstStatLocal
	| AstStatFor
	| AstStatForIn
	| AstStatAssign
	| AstStatCompoundAssign
	| AstStatFunction
	| AstStatLocalFunction
	| AstStatTypeAlias
	| AstStatTypeFunction

export type AstGenericType = {
	read tag: "generic",
	read name: Token<string>,
	read equals: Token<"=">?,
	read default: AstType?,
}

export type AstGenericTypePack = {
	read tag: "genericpack",
	read name: Token<string>,
	read ellipsis: Token<"...">,
	read equals: Token<"=">?,
	read default: AstTypePack?,
}

export type AstTypeReference = {
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

export type AstTypeSingletonBool = {
	read location: Span,
	read kind: "type",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}

export type AstTypeSingletonString = {
	read location: Span,
	read kind: "type",
	read tag: "string",
	read quoteStyle: "single" | "double",
	read token: Token<string>,
}

export type AstTypeTypeof = {
	read location: Span,
	read kind: "type",
	read tag: "typeof",
	read typeof: Token<"typeof">,
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}

export type AstTypeGroup = {
	read location: Span,
	read kind: "type",
	read tag: "group",
	read openParens: Token<"(">,
	read type: AstType,
	read closeParens: Token<")">,
}

export type AstTypeOptional = { read location: Span, read kind: "type", read tag: "optional", read token: Token<"?"> }

export type AstTypeUnion = {
	read location: Span,
	read kind: "type",
	read tag: "union",
	read leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	read types: Punctuated<AstType, "|">,
}

export type AstTypeIntersection = {
	read location: Span,
	read kind: "type",
	read tag: "intersection",
	read leading: Token<"&">?,
	read types: Punctuated<AstType, "&">,
}

export type AstTypeArray = {
	read location: Span,
	read kind: "type",
	read tag: "array",
	read openBrace: Token<"{">,
	read access: Token<"read" | "write">?,
	read type: AstType,
	read closeBrace: Token<"}">,
}

export type AstTableTypeItemIndexer = {
	read kind: "indexer",
	read access: Token<"read" | "write">?,
	read indexerOpen: Token<"[">,
	read key: AstType,
	read indexerClose: Token<"]">,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

export type AstTableTypeItemStringProperty = {
	read kind: "stringproperty",
	read access: Token<"read" | "write">?,
	read indexerOpen: Token<"[">,
	read key: AstTypeSingletonString,
	read indexerClose: Token<"]">,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

export type AstTableTypeItemProperty = {
	read kind: "property",
	read access: Token<"read" | "write">?,
	read key: Token,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

export type AstTableTypeItem = AstTableTypeItemIndexer | AstTableTypeItemStringProperty | AstTableTypeItemProperty

export type AstTypeTable = {
	read location: Span,
	read kind: "type",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableTypeItem },
	read closeBrace: Token<"}">,
}

export type AstFunctionTypeParameter = {
	read location: Span,
	read name: Token?,
	read colon: Token<":">?,
	read type: AstType,
}

-- A type representing a Luau function
export type AstTypeFunction = {
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

export type AstType =
	| AstTypeReference
	| AstTypeSingletonBool
	| AstTypeSingletonString
	| AstTypeTypeof
	| AstTypeGroup
	| AstTypeUnion
	| AstTypeIntersection
	| AstTypeOptional
	| AstTypeArray
	| AstTypeTable
	| AstTypeFunction

export type AstTypePackExplicit = {
	read location: Span,
	read kind: "typepack",
	read tag: "explicit",
	read openParens: Token<"(">?,
	read types: Punctuated<AstType>,
	read tailType: AstTypePack?,
	read closeParens: Token<")">?,
}

export type AstTypePackGeneric = {
	read location: Span,
	read kind: "typepack",
	read tag: "generic",
	read name: Token,
	read ellipsis: Token<"...">,
}

export type AstTypePackVariadic = {
	read location: Span,
	read kind: "typepack",
	read tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	read ellipsis: Token<"...">?,
	read type: AstType,
}

export type AstTypePack = AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic

export type AstNode = AstExpr | AstStat | AstType | AstTypePack | AstLocal | AstAttribute | Token

export type ParseResult = {
	read root: AstStatBlock,
	read eof: Eof,
	read lines: number,
	read lineOffsets: { number },
}

function luau.parse(source: string): ParseResult
	error("not implemented")
end

function luau.parseExpr(source: string): AstExpr
	error("not implemented")
end

export type Bytecode = { bytecode: string }

function luau.compile(source: string): Bytecode
	error("not implemented")
end

function luau.load(bytecode: Bytecode, chunkname: string, env: { [any]: any }?): (...any) -> ...any
	error("not implemented")
end

function luau.resolveModule(path: string, fromchunkname: string): string
	error("not implemented")
end

export type Type = {
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
	-- TODO: writeindexer: { index: type, result: type } }?,
	metatable: Type?,

	-- for function type
	parameters: TypePack,
	argnames: { string? },
	returns: TypePack,
	generics: { Type },
	genericpacks: { TypePack },

	-- for extern type
	-- 'properties', 'metatable' are shared with table type
	parent: Type?,

	-- for generic type
	name: string,
	ispack: boolean,
}

export type TypePack = {
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

function luau.typeofmodule(modulepath: string): (TypePack, {[string]: Type})
	error("not implemented")
end

return luau
