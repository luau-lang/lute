local luau = {}

-- this is a userdata, not a table, but it has this interface
export type span = {
	beginline: number,
	begincolumn: number,
	endline: number,
	endcolumn: number,
}

luau.span = {}

span.create(1, 2, 3, 4)

span.create {
    beginline = 1,
    begincolumn = 2,
    endline = 3,
    endcolumn = 4,
}

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
	kind: "local",
	name: Token<string>,
	colon: Token<":">?,
	annotation: AstType?,
	shadows: AstLocal?,
}

export type AstExprGroup = {
	tag: "group",
	openparens: Token<"(">,
	expression: AstExpr,
	closeparens: Token<")">,
}

export type AstExprConstantNil = Token<"nil"> & { kind: "expr", tag: "nil" }

export type AstExprConstantBool = Token<"true" | "false"> & { kind: "expr", tag: "boolean", value: boolean }

export type AstExprConstantNumber = Token<string> & { kind: "expr", tag: "number", value: number }

export type AstExprConstantString = Token<string> & {
	kind: "expr",
	tag: "string",
	quotestyle: "single" | "double" | "block" | "interp",
	blockdepth: number,
}

export type AstExprLocal = { kind: "expr", tag: "local", token: Token<string>, ["local"]: AstLocal, upvalue: boolean }

export type AstExprGlobal = { kind: "expr", tag: "global", name: Token }

export type AstExprVarargs = Token<"..."> & { kind: "expr", tag: "vararg" }

export type AstExprCall = {
	kind: "expr",
	tag: "call",
	func: AstExpr,
	openparens: Token<"(">?,
	arguments: Punctuated<AstExpr>,
	closeparens: Token<")">?,
	self: boolean,
	argLocation: span,
}

export type AstExprIndexName = {
	kind: "expr",
	tag: "indexname",
	expression: AstExpr,
	accessor: Token<"." | ":">,
	index: Token<string>,
	indexlocation: span,
}

export type AstExprIndexExpr = {
	kind: "expr",
	tag: "index",
	expression: AstExpr,
	openbrackets: Token<"[">,
	index: AstExpr,
	closebrackets: Token<"]">,
}

-- I don't like that we have this type; a lot of its data should live in the parents, which should then have `AstStatBlock` as its body
export type AstFunctionBody = {
	opengenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericpacks: Punctuated<AstGenericTypePack>?,
	closegenerics: Token<">">?,
	self: AstLocal?,
	openparens: Token<"(">,
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

export type AstExprAnonymousFunction = {
	kind: "expr",
	tag: "function",
	attributes: { AstAttribute },
	functionkeyword: Token<"function">,
	body: AstFunctionBody,
}

-- helper types for items contained in an AstExprTable, not actually AstExprs themselves
export type AstExprTableItemList = { kind: "list", value: AstExpr, separator: Token<"," | ";">?, istableitem: true }

export type AstExprTableItemRecord = {
	kind: "record",
	key: Token<string>,
	equals: Token<"=">,
	value: AstExpr,
	separator: Token<"," | ";">?,
	istableitem: true,
}

export type AstExprTableItemGeneral = {
	kind: "general",
	indexeropen: Token<"[">,
	key: AstExpr,
	indexerclose: Token<"]">,
	equals: Token<"=">,
	value: AstExpr,
	separator: Token<"," | ";">?,
	istableitem: true,
}

export type AstExprTableItem = AstExprTableItemList | AstExprTableItemRecord | AstExprTableItemGeneral

export type AstExprTable = {
	kind: "expr",
	tag: "table",
	openbrace: Token<"{">,
	entries: { AstExprTableItem },
	closebrace: Token<"}">,
}

export type AstExprUnary = { kind: "expr", tag: "unary", operator: Token<"not" | "-" | "#">, operand: AstExpr }

export type AstExprBinary = {
	kind: "expr",
	tag: "binary",
	lhsoperand: AstExpr,
	operator: Token, -- TODO: enforce token type
	rhsoperand: AstExpr,
}

export type AstExprInterpString = {
	kind: "expr",
	tag: "interpolatedstring",
	strings: { Token<string> },
	expressions: { AstExpr },
}

export type AstExprTypeAssertion = {
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
	| AstExprIndexName
	| AstExprIndexExpr
	| AstExprAnonymousFunction
	| AstExprTable
	| AstExprUnary
	| AstExprBinary
	| AstExprInterpString
	| AstExprTypeAssertion
	| AstExprIfElse
)

export type AstStatBlock = {
	kind: "stat",
	tag: "block",
	statements: { AstStat },
}

export type AstElseIfStat = {
	elseifkeyword: Token<"elseif">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenblock: AstStatBlock,
}

export type AstStatIf = {
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
	kind: "stat",
	tag: "while",
	whilekeyword: Token<"while">,
	condition: AstExpr,
	dokeyword: Token<"do">,
	body: AstStatBlock,
	endkeyword: Token<"end">,
}

export type AstStatRepeat = {
	kind: "stat",
	tag: "repeat",
	repeatkeyword: Token<"repeat">,
	body: AstStatBlock,
	untilkeyword: Token<"until">,
	condition: AstExpr,
}

export type AstStatBreak = Token<"break"> & { kind: "stat", tag: "break" }

export type AstStatContinue = Token<"continue"> & { kind: "stat", tag: "continue" }

export type AstStatReturn = {
	kind: "stat",
	tag: "return",
	returnkeyword: Token<"return">,
	expressions: Punctuated<AstExpr>,
}

export type AstStatExpr = { kind: "stat", tag: "expression", expression: AstExpr }

export type AstStatLocal = {
	kind: "stat",
	tag: "local",
	localkeyword: Token<"local">,
	variables: Punctuated<AstLocal>,
	equals: Token<"=">?,
	values: Punctuated<AstExpr>,
}

export type AstStatFor = {
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
	kind: "stat",
	tag: "assign",
	variables: Punctuated<AstExpr>,
	equals: Token<"=">,
	values: Punctuated<AstExpr>,
}

export type AstStatCompoundAssign = {
	kind: "stat",
	tag: "compoundassign",
	variable: AstExpr,
	operand: Token, -- TODO: enforce token type,
	value: AstExpr,
}

export type AstAttribute = Token<"@checked" | "@native" | "@deprecated"> & { kind: "attribute" }

export type AstStatFunction = {
	kind: "stat",
	tag: "function",
	attributes: { AstAttribute },
	functionkeyword: Token<"function">,
	name: AstExpr,
	body: AstFunctionBody,
}

export type AstStatLocalFunction = {
	kind: "stat",
	tag: "localfunction",
	attributes: { AstAttribute },
	localkeyword: Token<"local">,
	functionkeyword: Token<"function">,
	name: AstLocal,
	body: AstFunctionBody,
}

export type AstStatTypeAlias = {
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

export type AstStatTypeFunction = {
	kind: "stat",
	tag: "typefunction",
	export: Token<"export">?,
	type: Token<"type">,
	functionkeyword: Token<"function">,
	name: Token,
	body: AstFunctionBody,
}

export type AstStat = { kind: "stat" } & (
	| AstStatBlock
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
	kind: "type",
	tag: "reference",
	prefix: Token<string>?,
	prefixpoint: Token<".">?,
	name: Token<string>,
	openparameters: Token<"<">?,
	parameters: Punctuated<AstType | AstTypePack>?,
	closeparameters: Token<">">?,
}

export type AstTypeSingletonBool = Token<"true" | "false"> & { kind: "type", tag: "boolean", value: boolean }

export type AstTypeSingletonString = Token<string> & { kind: "type", tag: "string", quotestyle: "single" | "double" }

export type AstTypeTypeof = {
	kind: "type",
	tag: "typeof",
	typeof: Token<"typeof">,
	openparens: Token<"(">,
	expression: AstExpr,
	closeparens: Token<")">,
}

export type AstTypeGroup = {
	kind: "type",
	tag: "group",
	openparens: Token<"(">,
	type: AstType,
	closeparens: Token<")">,
}

export type AstTypeOptional = Token<"?"> & { kind: "type", tag: "optional" }

export type AstTypeUnion = {
	kind: "type",
	tag: "union",
	leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	types: Punctuated<AstType, "|">,
}

export type AstTypeIntersection = {
	kind: "type",
	tag: "intersection",
	leading: Token<"&">?,
	types: Punctuated<AstType, "&">,
}

export type AstTypeArray = {
	kind: "type",
	tag: "array",
	openbrace: Token<"{">,
	access: Token<"read" | "write">?,
	type: AstType,
	closebrace: Token<"}">,
}

export type AstTypeTableItemIndexer = {
	kind: "indexer",
	access: Token<"read" | "write">?,
	indexeropen: Token<"[">,
	key: AstType,
	indexerclose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTypeTableItemStringProperty = {
	kind: "stringproperty",
	access: Token<"read" | "write">?,
	indexeropen: Token<"[">,
	key: AstTypeSingletonString,
	indexerclose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTypeTableItemProperty = {
	kind: "property",
	access: Token<"read" | "write">?,
	key: Token,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTypeTableItem = AstTypeTableItemIndexer | AstTypeTableItemStringProperty | AstTypeTableItemProperty

export type AstTypeTable = {
	kind: "type",
	tag: "table",
	openbrace: Token<"{">,
	entries: { AstTypeTableItem },
	closebrace: Token<"}">,
}

export type AstTypeFunctionParameter = {
	name: Token?,
	colon: Token<":">?,
	type: AstType,
}

export type AstTypeFunction = {
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
	kind: "typepack",
	tag: "explicit",
	openparens: Token<"(">?,
	types: Punctuated<AstType>,
	tailtype: AstTypePack?,
	closeparens: Token<")">?,
}

export type AstTypePackGeneric = { kind: "typepack", tag: "generic", name: Token, ellipsis: Token<"..."> }

export type AstTypePackVariadic = {
	kind: "typepack",
	tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	ellipsis: Token<"...">?,
	type: AstType,
}

export type AstTypePack = { kind: "typepack" } & (AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic)

export type AstNode = { location: span? } & (AstExpr | AstStat | AstType | AstTypePack | AstLocal | AstAttribute)

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

-- For now, we return a string representation of the module's type, but we will expand it to some Luau data structure representation of Type (similar to the AST types) in a subsequent PR.
function luau.typeofmodule(modulepath: string): string
	error("not implemented")
end

return luau
