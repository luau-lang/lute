local luau = {}

export type Position = {
	line: number,
	column: number,
}

export type Location = {
	begin: Position,
	["end"]: Position, -- TODO: do we really want to have to use brackets everywhere?
}

export type Whitespace = {
	tag: "whitespace",
	location: Location,
	text: string,
}

export type SingleLineComment = {
	tag: "comment",
	location: Location,
	text: string,
}

export type MultiLineComment = {
	tag: "blockcomment",
	location: Location,
	text: string,
	-- TODO: depth: number,
}

export type Trivia = Whitespace | SingleLineComment | MultiLineComment

export type Token<Kind = string> = {
	leadingtrivia: { Trivia },
	position: Position,
	text: Kind,
	trailingtrivia: { Trivia },
}

export type Eof = Token<""> & { tag: "eof" }

export type Pair<T, Separator> = { node: T, separator: Token<Separator>? }
export type Punctuated<T, Separator = ","> = { Pair<T, Separator> }

export type AstLocal = {
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

export type AstExprConstantNil = Token<"nil"> & { tag: "nil" }

export type AstExprConstantBool = Token<"true" | "false"> & { tag: "boolean", value: boolean }

export type AstExprConstantNumber = Token<string> & { tag: "number", value: number }

export type AstExprConstantString = Token<string> & {
	tag: "string",
	quotestyle: "single" | "double" | "block" | "interp",
	blockdepth: number,
}

export type AstExprLocal = {
	tag: "local",
	token: Token<string>,
	["local"]: AstLocal,
	upvalue: boolean,
}

export type AstExprGlobal = {
	tag: "global",
	name: Token,
}

export type AstExprVarargs = Token<"..."> & { tag: "vararg" }

export type AstExprCall = {
	tag: "call",
	func: AstExpr,
	openparens: Token<"(">?,
	arguments: Punctuated<AstExpr>,
	closeparens: Token<")">?,
	self: boolean,
	argLocation: Location,
}

export type AstExprIndexName = {
	tag: "indexname",
	expression: AstExpr,
	accessor: Token<"." | ":">,
	index: Token<string>,
	indexlocation: Location,
}

export type AstExprIndexExpr = {
	tag: "index",
	expression: AstExpr,
	openbrackets: Token<"[">,
	index: AstExpr,
	closebrackets: Token<"]">,
}

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
	tag: "function",
	attributes: { AstAttribute },
	functionkeyword: Token<"function">,
	body: AstFunctionBody,
}

export type AstExprTableItem = | { kind: "list", value: AstExpr, separator: Token<"," | ";">? } | {
	kind: "record",
	key: Token<string>,
	equals: Token<"=">,
	value: AstExpr,
	separator: Token<"," | ";">?,
} | {
	kind: "general",
	indexeropen: Token<"[">,
	key: AstExpr,
	indexerclose: Token<"]">,
	equals: Token<"=">,
	value: AstExpr,
	separator: Token<"," | ";">?,
}

export type AstExprTable = {
	tag: "table",
	openbrace: Token<"{">,
	entries: { AstExprTableItem },
	closebrace: Token<"}">,
}

export type AstExprUnary = {
	tag: "unary",
	operator: Token<"not" | "-" | "#">,
	operand: AstExpr,
}

export type AstExprBinary = {
	tag: "binary",
	lhsoperand: AstExpr,
	operator: Token, -- TODO: enforce token type
	rhsoperand: AstExpr,
}

export type AstExprInterpString = {
	tag: "interpolatedstring",
	strings: { Token<string> },
	expressions: { AstExpr },
}

export type AstExprTypeAssertion = {
	tag: "cast",
	operand: AstExpr,
	operator: Token<"::">,
	annotation: AstType,
}

export type AstExprIfElseIfs = {
	elseifkeyword: Token<"elseif">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenexpr: AstExpr,
}

export type AstExprIfElse = {
	tag: "conditional",
	ifkeyword: Token<"if">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenexpr: AstExpr,
	elseifs: { AstExprIfElseIfs },
	elsekeyword: Token<"else">,
	elseexpr: AstExpr,
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
	| AstExprIndexName
	| AstExprIndexExpr
	| AstExprAnonymousFunction
	| AstExprTable
	| AstExprUnary
	| AstExprBinary
	| AstExprInterpString
	| AstExprTypeAssertion
	| AstExprIfElse

export type AstStatBlock = {
	tag: "block",
	statements: { AstStat },
}

export type AstStatElseIf = {
	elseifkeyword: Token<"elseif">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenblock: AstStatBlock,
}

export type AstStatIf = {
	tag: "conditional",
	ifkeyword: Token<"if">,
	condition: AstExpr,
	thenkeyword: Token<"then">,
	thenblock: AstStatBlock,
	elseifs: { AstStatElseIf },
	elsekeyword: Token<"else">?, -- TODO: this could be elseif!
	elseblock: AstStatBlock?,
	endkeyword: Token<"end">,
}

export type AstStatWhile = {
	tag: "while",
	whilekeyword: Token<"while">,
	condition: AstExpr,
	dokeyword: Token<"do">,
	body: AstStatBlock,
	endkeyword: Token<"end">,
}

export type AstStatRepeat = {
	tag: "repeat",
	repeatKeyword: Token<"repeat">,
	body: AstStatBlock,
	untilKeyword: Token<"until">,
	condition: AstExpr,
}

export type AstStatBreak = Token<"break"> & { tag: "break" }

export type AstStatContinue = Token<"continue"> & { tag: "continue" }

export type AstStatReturn = {
	tag: "return",
	returnkeyword: Token<"return">,
	expressions: Punctuated<AstExpr>,
}

export type AstStatExpr = {
	tag: "expression",
	expression: AstExpr,
}

export type AstStatLocal = {
	tag: "local",
	localkeyword: Token<"local">,
	variables: Punctuated<AstLocal>,
	equals: Token<"=">?,
	values: Punctuated<AstExpr>,
}

export type AstStatFor = {
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
	tag: "assign",
	variables: Punctuated<AstExpr>,
	equals: Token<"=">,
	values: Punctuated<AstExpr>,
}

export type AstStatCompoundAssign = {
	tag: "compoundassign",
	variable: AstExpr,
	operand: Token, -- TODO: enforce token type,
	value: AstExpr,
}

export type AstAttribute = Token<"@checked" | "@native" | "@deprecated"> & { tag: "attribute" }

export type AstStatFunction = {
	tag: "function",
	attributes: { AstAttribute },
	functionkeyword: Token<"function">,
	name: AstExpr,
	body: AstFunctionBody,
}

export type AstStatLocalFunction = {
	tag: "localfunction",
	attributes: { AstAttribute },
	localkeyword: Token<"local">,
	functionkeyword: Token<"function">,
	name: AstLocal,
	body: AstFunctionBody,
}

export type AstStatTypeAlias = {
	tag: "typealias",
	export: Token<"export">?,
	typeToken: Token<"type">,
	name: Token,
	opengenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericpacks: Punctuated<AstGenericTypePack>?,
	closegenerics: Token<">">?,
	equals: Token<"=">,
	type: AstType,
}

export type AstStatTypeFunction = {
	tag: "typefunction",
	export: Token<"export">?,
	type: Token<"type">,
	functionkeyword: Token<"function">,
	name: Token,
	body: AstFunctionBody,
}

export type AstStat =
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
	tag: "reference",
	prefix: Token<string>?,
	prefixpoint: Token<".">?,
	name: Token<string>,
	openparameters: Token<"<">?,
	parameters: Punctuated<AstType | AstTypePack>?,
	closeparameters: Token<">">?,
}

export type AstTypeSingletonBool = Token<"true" | "false"> & {
	tag: "boolean",
	value: boolean,
}

export type AstTypeSingletonString = Token<string> & {
	tag: "string",
	quotestyle: "single" | "double",
}

export type AstTypeTypeof = {
	tag: "typeof",
	typeof: Token<"typeof">,
	openparens: Token<"(">,
	expression: AstExpr,
	closeparens: Token<")">,
}

export type AstTypeGroup = {
	tag: "group",
	openparens: Token<"(">,
	type: AstType,
	closeparens: Token<">">,
}

export type AstTypeOptional = Token<"?"> & { tag: "optional" }

export type AstTypeUnion = {
	tag: "union",
	leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	types: Punctuated<AstType, "|">,
}

export type AstTypeIntersection = {
	tag: "intersection",
	leading: Token<"&">?,
	types: Punctuated<AstType, "&">,
}

export type AstTypeArray = {
	tag: "array",
	openbrace: Token<"{">,
	access: Token<"read" | "write">?,
	type: AstType,
	closebrace: Token<"}">,
}

export type AstTypeTableItem = {
	kind: "indexer",
	access: Token<"read" | "write">?,
	indexeropen: Token<"[">,
	key: AstType,
	indexerclose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
} | {
	kind: "stringproperty",
	access: Token<"read" | "write">?,
	indexeropen: Token<"[">,
	key: AstTypeSingletonString,
	indexerclose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
} | {
	kind: "property",
	access: Token<"read" | "write">?,
	key: AstTypeSingletonString,
	indexerclose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTypeTable = {
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
	tag: "explicit",
	openparens: Token<"(">?,
	types: Punctuated<AstType>,
	tailtype: AstTypePack?,
	closeparens: Token<")">?,
}

export type AstTypePackGeneric = {
	tag: "generic",
	name: Token,
	ellipsis: Token<"...">,
}

export type AstTypePackVariadic = {
	tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	ellipsis: Token<"...">?,
	type: AstType,
}

export type AstTypePack = AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic

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

return luau
