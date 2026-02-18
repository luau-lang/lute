-- lute-lint-global-ignore(unused_variable)
local luau = {}

-- this is a userdata, not a table, but it has this interface
type spandata = {
	beginline: number,
	begincolumn: number,
	endline: number,
	endcolumn: number,
}
type spanMT = {
	__lt: (a: spandata, b: spandata) -> boolean,
}
export type span = setmetatable<spandata, spanMT>

luau.span = {}

function luau.span.create(tbl: { beginline: number, begincolumn: number, endline: number, endcolumn: number }): span
	error("not implemented")
end

export type Whitespace = {
	tag: "whitespace",
	location: span,
	text: string,
}

export type SingleLineComment = {
	tag: "comment",
	location: span,
	text: string,
}

export type MultiLineComment = {
	tag: "blockcomment",
	location: span,
	text: string,
	-- TODO: depth: number,
}

export type Trivia = Whitespace | SingleLineComment | MultiLineComment

export type Token<Kind = string> = {
	leadingtrivia: { Trivia },
	location: span,
	text: Kind,
	trailingtrivia: { Trivia },
	istoken: true,
}

export type Eof = Token<""> & { tag: "eof" }

export type Pair<T, Separator> = { node: T, separator: Token<Separator>? }
export type Punctuated<T, Separator = ","> = { Pair<T, Separator> }

export type AstLocal = {
	read location: span,
	read kind: "local",
	read name: Token<string>,
	read colon: Token<":">?,
	read annotation: AstType?,
	read shadows: AstLocal?,
}

export type AstExprGroup = {
	read location: span,
	read kind: "expr",
	read tag: "group",
	read openparens: Token<"(">,
	read expression: AstExpr,
	read closeparens: Token<")">,
}

export type AstExprConstantNil = Token<"nil"> & { read location: span, read kind: "expr", read tag: "nil" }

export type AstExprConstantBool = Token<"true" | "false"> & {
	read location: span,
	read kind: "expr",
	read tag: "boolean",
	read value: boolean,
}

export type AstExprConstantNumber = Token<string> & {
	read location: span,
	read kind: "expr",
	read tag: "number",
	read value: number,
}

export type AstExprConstantString = Token<string> & {
	read location: span,
	read kind: "expr",
	read tag: "string",
	read quotestyle: "single" | "double" | "block" | "interp",
	read blockdepth: number,
}

export type AstExprLocal = {
	read location: span,
	read kind: "expr",
	read tag: "local",
	read token: Token<string>,
	read ["local"]: AstLocal,
	read upvalue: boolean,
}

export type AstExprGlobal = { read location: span, read kind: "expr", read tag: "global", read name: Token }

export type AstExprVarargs = Token<"..."> & { read location: span, read kind: "expr", read tag: "vararg" }

export type AstExprCall = {
	read location: span,
	read kind: "expr",
	read tag: "call",
	read func: AstExpr,
	read openparens: Token<"(">?,
	read arguments: Punctuated<AstExpr>,
	read closeparens: Token<")">?,
	read self: boolean,
	read argLocation: span,
}

export type AstExprInstantiate = {
	read location: span,
	read kind: "expr",
	read tag: "instantiate",
	read expr: AstExpr,
	read leftarrow1: Token<"<">,
	read leftarrow2: Token<"<">,
	read typearguments: Punctuated<AstType | AstTypePack>,
	read rightarrow1: Token<">">,
	read rightarrow2: Token<">">,
}

export type AstExprIndexName = {
	read location: span,
	read kind: "expr",
	read tag: "indexname",
	read expression: AstExpr,
	read accessor: Token<"." | ":">,
	read index: Token<string>,
	read indexlocation: span,
}

export type AstExprIndexExpr = {
	read location: span,
	read kind: "expr",
	read tag: "index",
	read expression: AstExpr,
	read openbrackets: Token<"[">,
	read index: AstExpr,
	read closebrackets: Token<"]">,
}

export type AstExprFunction = {
	read location: span,
	read kind: "expr",
	read tag: "function",
	read attributes: { AstAttribute },
	read functionkeyword: Token<"function">,
	read opengenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericpacks: Punctuated<AstGenericTypePack>?,
	read closegenerics: Token<">">?,
	read openparens: Token<"(">,
	read self: AstLocal?,
	read parameters: Punctuated<AstLocal>,
	read vararg: Token<"...">?,
	read varargcolon: Token<":">?,
	read varargannotation: AstTypePack?,
	read closeparens: Token<")">,
	read returnspecifier: Token<":">?,
	read returnannotation: AstTypePack?,
	read body: AstStatBlock,
	read endkeyword: Token<"end">,
}

-- helper types for items contained in an AstExprTable, not actually AstExprs themselves
export type AstTableExprListItem = {
	read location: span,
	read kind: "list",
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read istableitem: true,
}

export type AstTableExprRecordItem = {
	read location: span,
	read kind: "record",
	read key: Token<string>,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read istableitem: true,
}

export type AstTableExprGeneralItem = {
	read location: span,
	read kind: "general",
	read indexeropen: Token<"[">,
	read key: AstExpr,
	read indexerclose: Token<"]">,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read istableitem: true,
}

export type AstTableExprItem = AstTableExprListItem | AstTableExprRecordItem | AstTableExprGeneralItem

export type AstExprTable = {
	read location: span,
	read kind: "expr",
	read tag: "table",
	read openbrace: Token<"{">,
	read entries: { AstTableExprItem },
	read closebrace: Token<"}">,
}

export type AstExprUnary = {
	read location: span,
	read kind: "expr",
	read tag: "unary",
	read operator: Token<"not" | "-" | "#">,
	read operand: AstExpr,
}

export type AstExprBinary = {
	read location: span,
	read kind: "expr",
	read tag: "binary",
	read lhsoperand: AstExpr,
	read operator: Token,
	read rhsoperand: AstExpr,
}

export type AstExprInterpString = {
	read location: span,
	read kind: "expr",
	read tag: "interpolatedstring",
	read strings: { Token<string> },
	read expressions: { AstExpr },
}

export type AstExprTypeAssertion = {
	read location: span,
	read kind: "expr",
	read tag: "cast",
	read operand: AstExpr,
	read operator: Token<"::">,
	read annotation: AstType,
}

-- helper type for elseif clauses of an if-else expression, not actually an AstExpr itself
export type AstElseIfExpr = {
	read elseifkeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenkeyword: Token<"then">,
	read thenexpr: AstExpr,
}

export type AstExprIfElse = {
	read location: span,
	read kind: "expr",
	read tag: "conditional",
	read ifkeyword: Token<"if">,
	read condition: AstExpr,
	read thenkeyword: Token<"then">,
	read thenexpr: AstExpr,
	read elseifs: { AstElseIfExpr },
	read elsekeyword: Token<"else">,
	read elseexpr: AstExpr,
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
	read location: span,
	read kind: "stat",
	read tag: "block",
	read statements: { AstStat },
}

export type AstStatDo = {
	read location: span,
	read kind: "stat",
	read tag: "do",
	read dokeyword: Token<"do">,
	read body: AstStatBlock,
	read endkeyword: Token<"end">,
}

export type AstElseIfStat = {
	read elseifkeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenkeyword: Token<"then">,
	read thenblock: AstStatBlock,
}

export type AstStatIf = {
	read location: span,
	read kind: "stat",
	read tag: "conditional",
	read ifkeyword: Token<"if">,
	read condition: AstExpr,
	read thenkeyword: Token<"then">,
	read thenblock: AstStatBlock,
	read elseifs: { AstElseIfStat },
	read elsekeyword: Token<"else">?, -- TODO: This could be elseif!
	read elseblock: AstStatBlock?,
	read endkeyword: Token<"end">,
}

export type AstStatWhile = {
	read location: span,
	read kind: "stat",
	read tag: "while",
	read whilekeyword: Token<"while">,
	read condition: AstExpr,
	read dokeyword: Token<"do">,
	read body: AstStatBlock,
	read endkeyword: Token<"end">,
}

export type AstStatRepeat = {
	read location: span,
	read kind: "stat",
	read tag: "repeat",
	read repeatkeyword: Token<"repeat">,
	read body: AstStatBlock,
	read untilkeyword: Token<"until">,
	read condition: AstExpr,
}

export type AstStatBreak = Token<"break"> & { read location: span, read kind: "stat", read tag: "break" }

export type AstStatContinue = Token<"continue"> & { read location: span, read kind: "stat", read tag: "continue" }

export type AstStatReturn = {
	read location: span,
	read kind: "stat",
	read tag: "return",
	read returnkeyword: Token<"return">,
	read expressions: Punctuated<AstExpr>,
}

export type AstStatExpr = {
	read location: span,
	read kind: "stat",
	read tag: "expression",
	read expression: AstExpr,
}

export type AstStatLocal = {
	read location: span,
	read kind: "stat",
	read tag: "local",
	read localkeyword: Token<"local">,
	read variables: Punctuated<AstLocal>,
	read equals: Token<"=">?,
	read values: Punctuated<AstExpr>,
}

export type AstStatFor = {
	read location: span,
	read kind: "stat",
	read tag: "for",
	read forkeyword: Token<"for">,
	read variable: AstLocal,
	read equals: Token<"=">,
	read from: AstExpr,
	read tocomma: Token<",">,
	read to: AstExpr,
	read stepcomma: Token<",">?,
	read step: AstExpr?,
	read dokeyword: Token<"do">,
	read body: AstStatBlock,
	read endkeyword: Token<"end">,
}

export type AstStatForIn = {
	read location: span,
	read kind: "stat",
	read tag: "forin",
	read forkeyword: Token<"for">,
	read variables: Punctuated<AstLocal>,
	read inkeyword: Token<"in">,
	read values: Punctuated<AstExpr>,
	read dokeyword: Token<"do">,
	read body: AstStatBlock,
	read endkeyword: Token<"end">,
}

export type AstStatAssign = {
	read location: span,
	read kind: "stat",
	read tag: "assign",
	read variables: Punctuated<AstExpr>,
	read equals: Token<"=">,
	read values: Punctuated<AstExpr>,
}

export type AstStatCompoundAssign = {
	read location: span,
	read kind: "stat",
	read tag: "compoundassign",
	read variable: AstExpr,
	read operand: Token, -- TODO: Enforce token type
	read value: AstExpr,
}

export type AstAttribute = Token<"@checked" | "@native" | "@deprecated"> & { read location: span, read kind: "attribute" }

export type AstStatFunction = {
	read location: span,
	read kind: "stat",
	read tag: "function",
	read name: AstExpr,
	read func: AstExprFunction,
}

export type AstStatLocalFunction = {
	read location: span,
	read kind: "stat",
	read tag: "localfunction",
	read localkeyword: Token<"local">,
	read name: AstLocal,
	read func: AstExprFunction,
}

export type AstStatTypeAlias = {
	read location: span,
	read kind: "stat",
	read tag: "typealias",
	read export: Token<"export">?,
	read typetoken: Token<"type">,
	read name: Token,
	read opengenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericpacks: Punctuated<AstGenericTypePack>?,
	read closegenerics: Token<">">?,
	read equals: Token<"=">,
	read type: AstType,
}

-- A type function
export type AstStatTypeFunction = {
	read location: span,
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
	read location: span,
	read kind: "type",
	read tag: "reference",
	read prefix: Token<string>?,
	read prefixpoint: Token<".">?,
	read name: Token<string>,
	read openparameters: Token<"<">?,
	read parameters: Punctuated<AstType | AstTypePack>?,
	read closeparameters: Token<">">?,
}

export type AstTypeSingletonBool = Token<"true" | "false"> & {
	read location: span,
	read kind: "type",
	read tag: "boolean",
	read value: boolean,
}

export type AstTypeSingletonString = Token<string> & {
	read location: span,
	read kind: "type",
	read tag: "string",
	read quotestyle: "single" | "double",
}

export type AstTypeTypeof = {
	read location: span,
	read kind: "type",
	read tag: "typeof",
	read typeof: Token<"typeof">,
	read openparens: Token<"(">,
	read expression: AstExpr,
	read closeparens: Token<")">,
}

export type AstTypeGroup = {
	read location: span,
	read kind: "type",
	read tag: "group",
	read openparens: Token<"(">,
	read type: AstType,
	read closeparens: Token<")">,
}

export type AstTypeOptional = Token<"?"> & { read location: span, read kind: "type", read tag: "optional" }

export type AstTypeUnion = {
	read location: span,
	read kind: "type",
	read tag: "union",
	read leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	read types: Punctuated<AstType, "|">,
}

export type AstTypeIntersection = {
	read location: span,
	read kind: "type",
	read tag: "intersection",
	read leading: Token<"&">?,
	read types: Punctuated<AstType, "&">,
}

export type AstTypeArray = {
	read location: span,
	read kind: "type",
	read tag: "array",
	read openbrace: Token<"{">,
	read access: Token<"read" | "write">?,
	read type: AstType,
	read closebrace: Token<"}">,
}

export type AstTableTypeItemIndexer = {
	read kind: "indexer",
	read access: Token<"read" | "write">?,
	read indexeropen: Token<"[">,
	read key: AstType,
	read indexerclose: Token<"]">,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

export type AstTableTypeItemStringProperty = {
	read kind: "stringproperty",
	read access: Token<"read" | "write">?,
	read indexeropen: Token<"[">,
	read key: AstTypeSingletonString,
	read indexerclose: Token<"]">,
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
	read location: span,
	read kind: "type",
	read tag: "table",
	read openbrace: Token<"{">,
	read entries: { AstTableTypeItem },
	read closebrace: Token<"}">,
}

export type AstFunctionTypeParameter = {
	read location: span,
	read name: Token?,
	read colon: Token<":">?,
	read type: AstType,
}

-- A type representing a Luau function
export type AstTypeFunction = {
	read location: span,
	read kind: "type",
	read tag: "function",
	read opengenerics: Token<"<">?,
	read generics: Punctuated<AstGenericType>?,
	read genericpacks: Punctuated<AstGenericTypePack>?,
	read closegenerics: Token<">">?,
	read openparens: Token<"(">,
	read parameters: Punctuated<AstFunctionTypeParameter>,
	read vararg: AstTypePack?,
	read closeparens: Token<")">,
	read returnarrow: Token<"->">,
	read returntypes: AstTypePack,
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
	read location: span,
	read kind: "typepack",
	read tag: "explicit",
	read openparens: Token<"(">?,
	read types: Punctuated<AstType>,
	read tailtype: AstTypePack?,
	read closeparens: Token<")">?,
}

export type AstTypePackGeneric = {
	read location: span,
	read kind: "typepack",
	read tag: "generic",
	read name: Token,
	read ellipsis: Token<"...">,
}

export type AstTypePackVariadic = {
	read location: span,
	read kind: "typepack",
	read tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	read ellipsis: Token<"...">?,
	read type: AstType,
}

export type AstTypePack = AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic

export type AstNode = AstExpr | AstStat | AstType | AstTypePack | AstLocal | AstAttribute

export type ParseResult = {
	read root: AstStatBlock,
	read eof: Eof,
	read lines: number,
	read lineoffsets: { number },
}

function luau.parse(source: string): ParseResult
	error("not implemented")
end

function luau.parseexpr(source: string): AstExpr
	error("not implemented")
end

export type Bytecode = { bytecode: string }

function luau.compile(source: string): Bytecode
	error("not implemented")
end

function luau.load(bytecode: Bytecode, chunkname: string, env: { [any]: any }?): (...any) -> ...any
	error("not implemented")
end

function luau.resolverequire(path: string, fromchunkname: string): string
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

function luau.typeofmodule(modulepath: string): TypePack?
	error("not implemented")
end

return luau
