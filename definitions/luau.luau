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
	location: span,
	kind: "local",
	name: Token<string>,
	colon: Token<":">?,
	annotation: AstType?,
	shadows: AstLocal?,
}

export type AstExprGroup = {
	location: span,
	tag: "group",
	openparens: Token<"(">,
	expression: AstExpr,
	closeparens: Token<")">,
}

export type AstExprConstantNil = Token<"nil"> & { location: span, kind: "expr", tag: "nil" }

export type AstExprConstantBool =
	Token<"true" | "false">
	& { location: span, kind: "expr", tag: "boolean", value: boolean }

export type AstExprConstantNumber = Token<string> & { location: span, kind: "expr", tag: "number", value: number }
export type AstExprConstantString = Token<string> & {
	location: span,
	kind: "expr",
	tag: "string",
	quotestyle: "single" | "double" | "block" | "interp",
	blockdepth: number,
}

export type AstExprLocal = {
	location: span,
	kind: "expr",
	tag: "local",
	token: Token<string>,
	["local"]: AstLocal,
	upvalue: boolean,
}

export type AstExprGlobal = { location: span, kind: "expr", tag: "global", name: Token }

export type AstExprVarargs = Token<"..."> & { location: span, kind: "expr", tag: "vararg" }

export type AstExprCall = {
	location: span,
	kind: "expr",
	tag: "call",
	func: AstExpr,
	openparens: Token<"(">?,
	arguments: Punctuated<AstExpr>,
	closeparens: Token<")">?,
	self: boolean,
	argLocation: span,
}

export type AstExprInstantiate = {
	location: span,
	kind: "expr",
	tag: "instantiate",
	expr: AstExpr,
	leftarrow1: Token<"<">,
	leftarrow2: Token<"<">,
	typearguments: Punctuated<AstType | AstTypePack>,
	rightarrow1: Token<">">,
	rightarrow2: Token<">">,
}

export type AstExprIndexName = {
	location: span,
	kind: "expr",
	tag: "indexname",
	expression: AstExpr,
	accessor: Token<"." | ":">,
	index: Token<string>,
	indexlocation: span,
}

export type AstExprIndexExpr = {
	location: span,
	kind: "expr",
	tag: "index",
	expression: AstExpr,
	openbrackets: Token<"[">,
	index: AstExpr,
	closebrackets: Token<"]">,
}

export type AstExprFunction = {
	location: span,
	kind: "expr",
	tag: "function",
	attributes: { AstAttribute },
	functionkeyword: Token<"function">,
	opengenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericpacks: Punctuated<AstGenericTypePack>?,
	closegenerics: Token<">">?,
	openparens: Token<"(">,
	self: AstLocal?,
	parameters: Punctuated<AstLocal>,
	vararg: Token<"...">?,
	varargcolon: Token<":">?,
	varargannotation: AstTypePack?,
	closeparens: Token<")">,
	returnspecifier: Token<":">?,
	returnannotation: AstTypePack?,
	body: AstStatBlock,
	endkeyword: Token<"end">,
}

-- helper types for items contained in an AstExprTable, not actually AstExprs themselves
export type AstTableExprListItem = {
	location: span,
	kind: "list",
	value: AstExpr,
	separator: Token<"," | ";">?,
	istableitem: true,
}

export type AstTableExprRecordItem = {
	location: span,
	kind: "record",
	key: Token<string>,
	equals: Token<"=">,
	value: AstExpr,
	separator: Token<"," | ";">?,
	istableitem: true,
}

export type AstTableExprGeneralItem = {
	location: span,
	kind: "general",
	indexeropen: Token<"[">,
	key: AstExpr,
	indexerclose: Token<"]">,
	equals: Token<"=">,
	value: AstExpr,
	separator: Token<"," | ";">?,
	istableitem: true,
}

export type AstTableExprItem = AstTableExprListItem | AstTableExprRecordItem | AstTableExprGeneralItem

export type AstExprTable = {
	location: span,
	kind: "expr",
	tag: "table",
	openbrace: Token<"{">,
	entries: { AstTableExprItem },
	closebrace: Token<"}">,
}

export type AstExprUnary = {
	location: span,
	kind: "expr",
	tag: "unary",
	operator: Token<"not" | "-" | "#">,
	operand: AstExpr,
}

export type AstExprBinary = {
	location: span,
	kind: "expr",
	tag: "binary",
	lhsoperand: AstExpr,
	operator: Token, -- TODO: enforce token type
	rhsoperand: AstExpr,
}

export type AstExprInterpString = {
	location: span,
	kind: "expr",
	tag: "interpolatedstring",
	strings: { Token<string> },
	expressions: { AstExpr },
}

export type AstExprTypeAssertion = {
	location: span,
	kind: "expr",
	tag: "cast",
	operand: AstExpr,
	operator: Token<"::">,
	annotation: AstType,
}

-- helper type for elseif clauses of an if-else expression, not actually an AstExpr itself
export type AstElseIfExpr = {
	elseifkeyword: Token<"elseif">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenexpr: AstExpr,
}

export type AstExprIfElse = {
	location: span,
	kind: "expr",
	tag: "conditional",
	ifkeyword: Token<"if">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenexpr: AstExpr,
	elseifs: { AstElseIfExpr },
	elsekeyword: Token<"else">,
	elseexpr: AstExpr,
}

export type AstExpr = { kind: "expr" } & (
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
)

export type AstStatBlock = {
	location: span,
	kind: "stat",
	tag: "block",
	statements: { AstStat },
}

export type AstStatDo = {
	location: span,
	kind: "stat",
	tag: "do",
	dokeyword: Token<"do">,
	body: AstStatBlock,
	endkeyword: Token<"end">,
}

export type AstElseIfStat = {
	elseifkeyword: Token<"elseif">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenblock: AstStatBlock,
}

export type AstStatIf = {
	location: span,
	kind: "stat",
	tag: "conditional",
	ifkeyword: Token<"if">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenblock: AstStatBlock,
	elseifs: { AstElseIfStat },
	elsekeyword: Token<"else">?, -- TODO: this could be elseif!
	elseblock: AstStatBlock?,
	endkeyword: Token<"end">,
}

export type AstStatWhile = {
	location: span,
	kind: "stat",
	tag: "while",
	whilekeyword: Token<"while">,
	condition: AstExpr,
	dokeyword: Token<"do">,
	body: AstStatBlock,
	endkeyword: Token<"end">,
}

export type AstStatRepeat = {
	location: span,
	kind: "stat",
	tag: "repeat",
	repeatkeyword: Token<"repeat">,
	body: AstStatBlock,
	untilkeyword: Token<"until">,
	condition: AstExpr,
}

export type AstStatBreak = Token<"break"> & { location: span, kind: "stat", tag: "break" }

export type AstStatContinue = Token<"continue"> & { location: span, kind: "stat", tag: "continue" }

export type AstStatReturn = {
	location: span,
	kind: "stat",
	tag: "return",
	returnkeyword: Token<"return">,
	expressions: Punctuated<AstExpr>,
}

export type AstStatExpr = { location: span, kind: "stat", tag: "expression", expression: AstExpr }

export type AstStatLocal = {
	location: span,
	kind: "stat",
	tag: "local",
	localkeyword: Token<"local">,
	variables: Punctuated<AstLocal>,
	equals: Token<"=">?,
	values: Punctuated<AstExpr>,
}

export type AstStatFor = {
	location: span,
	kind: "stat",
	tag: "for",
	forkeyword: Token<"for">,
	variable: AstLocal,
	equals: Token<"=">,
	from: AstExpr,
	tocomma: Token<",">,
	to: AstExpr,
	stepcomma: Token<",">?,
	step: AstExpr?,
	dokeyword: Token<"do">,
	body: AstStatBlock,
	endkeyword: Token<"end">,
}

export type AstStatForIn = {
	location: span,
	kind: "stat",
	tag: "forin",
	forkeyword: Token<"for">,
	variables: Punctuated<AstLocal>,
	inkeyword: Token<"in">,
	values: Punctuated<AstExpr>,
	dokeyword: Token<"do">,
	body: AstStatBlock,
	endkeyword: Token<"end">,
}

export type AstStatAssign = {
	location: span,
	kind: "stat",
	tag: "assign",
	variables: Punctuated<AstExpr>,
	equals: Token<"=">,
	values: Punctuated<AstExpr>,
}

export type AstStatCompoundAssign = {
	location: span,
	kind: "stat",
	tag: "compoundassign",
	variable: AstExpr,
	operand: Token, -- TODO: enforce token type,
	value: AstExpr,
}

export type AstAttribute = Token<"@checked" | "@native" | "@deprecated"> & { location: span, kind: "attribute" }

export type AstStatFunction = {
	location: span,
	kind: "stat",
	tag: "function",
	name: AstExpr,
	func: AstExprFunction,
}

export type AstStatLocalFunction = {
	location: span,
	kind: "stat",
	tag: "localfunction",
	localkeyword: Token<"local">,
	name: AstLocal,
	func: AstExprFunction,
}

export type AstStatTypeAlias = {
	location: span,
	kind: "stat",
	tag: "typealias",
	export: Token<"export">?,
	typetoken: Token<"type">,
	name: Token,
	opengenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericpacks: Punctuated<AstGenericTypePack>?,
	closegenerics: Token<">">?,
	equals: Token<"=">,
	type: AstType,
}

-- A type function
export type AstStatTypeFunction = {
	location: span,
	kind: "stat",
	tag: "typefunction",
	export: Token<"export">?,
	type: Token<"type">,
	name: Token,
	body: AstExprFunction,
}

export type AstStat = { kind: "stat" } & (
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
)

export type AstGenericType = {
	tag: "generic",
	name: Token<string>,
	equals: Token<"=">?,
	default: AstType?,
}

export type AstGenericTypePack = {
	tag: "genericpack",
	name: Token<string>,
	ellipsis: Token<"...">,
	equals: Token<"=">?,
	default: AstTypePack?,
}

export type AstTypeReference = {
	location: span,
	kind: "type",
	tag: "reference",
	prefix: Token<string>?,
	prefixpoint: Token<".">?,
	name: Token<string>,
	openparameters: Token<"<">?,
	parameters: Punctuated<AstType | AstTypePack>?,
	closeparameters: Token<">">?,
}

export type AstTypeSingletonBool =
	Token<"true" | "false">
	& { location: span, kind: "type", tag: "boolean", value: boolean }

export type AstTypeSingletonString = Token<string> & {
	location: span,
	kind: "type",
	tag: "string",
	quotestyle: "single" | "double",
}

export type AstTypeTypeof = {
	location: span,
	kind: "type",
	tag: "typeof",
	typeof: Token<"typeof">,
	openparens: Token<"(">,
	expression: AstExpr,
	closeparens: Token<")">,
}

export type AstTypeGroup = {
	location: span,
	kind: "type",
	tag: "group",
	openparens: Token<"(">,
	type: AstType,
	closeparens: Token<")">,
}

export type AstTypeOptional = Token<"?"> & { location: span, kind: "type", tag: "optional" }

export type AstTypeUnion = {
	location: span,
	kind: "type",
	tag: "union",
	leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	types: Punctuated<AstType, "|">,
}

export type AstTypeIntersection = {
	location: span,
	kind: "type",
	tag: "intersection",
	leading: Token<"&">?,
	types: Punctuated<AstType, "&">,
}

export type AstTypeArray = {
	location: span,
	kind: "type",
	tag: "array",
	openbrace: Token<"{">,
	access: Token<"read" | "write">?,
	type: AstType,
	closebrace: Token<"}">,
}

export type AstTableTypeItemIndexer = {
	kind: "indexer",
	access: Token<"read" | "write">?,
	indexeropen: Token<"[">,
	key: AstType,
	indexerclose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTableTypeItemStringProperty = {
	kind: "stringproperty",
	access: Token<"read" | "write">?,
	indexeropen: Token<"[">,
	key: AstTypeSingletonString,
	indexerclose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTableTypeItemProperty = {
	kind: "property",
	access: Token<"read" | "write">?,
	key: Token,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTableTypeItem = AstTableTypeItemIndexer | AstTableTypeItemStringProperty | AstTableTypeItemProperty

export type AstTypeTable = {
	location: span,
	kind: "type",
	tag: "table",
	openbrace: Token<"{">,
	entries: { AstTableTypeItem },
	closebrace: Token<"}">,
}

export type AstTypeFunctionParameter = {
	location: span,
	name: Token?,
	colon: Token<":">?,
	type: AstType,
}

-- A type representing a Luau function
export type AstTypeFunction = {
	location: span,
	kind: "type",
	tag: "function",
	opengenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericpacks: Punctuated<AstGenericTypePack>?,
	closegenerics: Token<">">?,
	openparens: Token<"(">,
	parameters: Punctuated<AstTypeFunctionParameter>,
	vararg: AstTypePack?,
	closeparens: Token<")">,
	returnarrow: Token<"->">,
	returntypes: AstTypePack,
}

export type AstType = { kind: "type" } & (
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
)

export type AstTypePackExplicit = {
	location: span,
	kind: "typepack",
	tag: "explicit",
	openparens: Token<"(">?,
	types: Punctuated<AstType>,
	tailtype: AstTypePack?,
	closeparens: Token<")">?,
}

export type AstTypePackGeneric = { location: span, kind: "typepack", tag: "generic", name: Token, ellipsis: Token<"..."> }

export type AstTypePackVariadic = {
	location: span,
	kind: "typepack",
	tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	ellipsis: Token<"...">?,
	type: AstType,
}

export type AstTypePack = { kind: "typepack" } & (AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic)

export type AstNode = { location: span } & (AstExpr | AstStat | AstType | AstTypePack | AstLocal | AstAttribute)

export type ParseResult = {
	root: AstStatBlock,
	eof: Eof,
	lines: number,
	lineoffsets: { number },
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
