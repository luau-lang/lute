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
	leadingTrivia: { Trivia },
	position: Position,
	text: Kind,
	trailingTrivia: { Trivia },
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
	openParens: Token<"(">,
	expression: AstExpr,
	closeParens: Token<")">,
}

export type AstExprConstantNil = Token<"nil"> & { tag: "nil" }

export type AstExprConstantBool = Token<"true" | "false"> & { tag: "boolean", value: boolean }

export type AstExprConstantNumber = Token<string> & { tag: "number", value: number }

export type AstExprConstantString = Token<string> & {
	tag: "string",
	quoteStyle: "single" | "double" | "block" | "interp",
	blockDepth: number,
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
	openParens: Token<"(">?,
	arguments: Punctuated<AstExpr>,
	closeParens: Token<")">?,
	self: boolean,
	argLocation: Location,
}

export type AstExprIndexName = {
	tag: "indexname",
	expression: AstExpr,
	accessor: Token<"." | ":">,
	index: Token<string>,
	indexLocation: Location,
}

export type AstExprIndexExpr = {
	tag: "index",
	expression: AstExpr,
	openBrackets: Token<"[">,
	index: AstExpr,
	closeBrackets: Token<"]">,
}

export type AstFunctionBody = {
	openGenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericPacks: Punctuated<AstGenericTypePack>?,
	closeGenerics: Token<">">?,
	self: AstLocal?,
	openParens: Token<"(">,
	parameters: Punctuated<AstLocal>,
	vararg: Token<"...">?,
	varargColon: Token<":">?,
	varargAnnotation: AstTypePack?,
	closeParens: Token<")">,
	returnSpecifier: Token<":">?,
	returnAnnotation: AstTypePack?,
	body: AstStatBlock,
	endKeyword: Token<"end">,
}

export type AstExprAnonymousFunction = {
	tag: "function",
	attributes: { AstAttribute },
	functionKeyword: Token<"function">,
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
	indexerOpen: Token<"[">,
	key: AstExpr,
	indexerClose: Token<"]">,
	equals: Token<"=">,
	value: AstExpr,
	separator: Token<"," | ";">?,
}

export type AstExprTable = {
	tag: "table",
	openBrace: Token<"{">,
	entries: { AstExprTableItem },
	closeBrace: Token<"}">,
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
	elseifKeyword: Token<"elseif">,
	condition: AstExpr,
	thenKeyword: Token<"then">,
	consequent: AstExpr,
}

export type AstExprIfElse = {
	tag: "conditional",
	ifKeyword: Token<"if">,
	condition: AstExpr,
	thenKeyword: Token<"then">,
	consequent: AstExpr,
	elseifs: { AstExprIfElseIfs },
	elseKeyword: Token<"else">,
	antecedent: AstExpr,
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
	elseifKeyword: Token<"elseif">,
	condition: AstExpr,
	thenKeyword: Token<"then">,
	consequent: AstStatBlock,
}

export type AstStatIf = {
	tag: "conditional",
	ifKeyword: Token<"if">,
	condition: AstExpr,
	thenKeyword: Token<"then">,
	consequent: AstStatBlock,
	elseifs: { AstStatElseIf },
	elseKeyword: Token<"else">?, -- TODO: this could be elseif!
	antecedent: AstStatBlock?,
	endKeyword: Token<"end">,
}

export type AstStatWhile = {
	tag: "while",
	whileKeyword: Token<"while">,
	condition: AstExpr,
	doKeyword: Token<"do">,
	body: AstStatBlock,
	endKeyword: Token<"end">,
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
	returnKeyword: Token<"return">,
	expressions: Punctuated<AstExpr>,
}

export type AstStatExpr = {
	tag: "expression",
	expression: AstExpr,
}

export type AstStatLocal = {
	tag: "local",
	localKeyword: Token<"local">,
	variables: Punctuated<AstLocal>,
	equals: Token<"=">?,
	values: Punctuated<AstExpr>,
}

export type AstStatFor = {
	tag: "for",
	forKeyword: Token<"for">,
	variable: AstLocal,
	equals: Token<"=">,
	from: AstExpr,
	toComma: Token<",">,
	to: AstExpr,
	stepComma: Token<",">?,
	step: AstExpr?,
	doKeyword: Token<"do">,
	body: AstStatBlock,
	endKeyword: Token<"end">,
}

export type AstStatForIn = {
	tag: "forin",
	forKeyword: Token<"for">,
	variables: Punctuated<Token<string>>,
	inKeyword: Token<"in">,
	values: Punctuated<AstExpr>,
	doKeyword: Token<"do">,
	body: AstStatBlock,
	endKeyword: Token<"end">,
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
	functionKeyword: Token<"function">,
	name: AstExpr,
	body: AstFunctionBody,
}

export type AstStatLocalFunction = {
	tag: "localfunction",
	attributes: { AstAttribute },
	localKeyword: Token<"local">,
	functionKeyword: Token<"function">,
	name: AstLocal,
	body: AstFunctionBody,
}

export type AstStatTypeAlias = {
	tag: "typealias",
	export: Token<"export">?,
	typeToken: Token<"type">,
	name: Token,
	openGenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericPacks: Punctuated<AstGenericTypePack>?,
	closeGenerics: Token<">">?,
	equals: Token<"=">,
	type: AstType,
}

export type AstStatTypeFunction = {
	tag: "typefunction",
	export: Token<"export">?,
	type: Token<"type">,
	functionKeyword: Token<"function">,
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
	prefixPoint: Token<".">?,
	name: Token<string>,
	openParameters: Token<"<">?,
	parameters: Punctuated<AstType | AstTypePack>?,
	closeParameters: Token<">">?,
}

export type AstTypeSingletonBool = Token<"true" | "false"> & {
	tag: "boolean",
	value: boolean,
}

export type AstTypeSingletonString = Token<string> & {
	tag: "string",
	quoteStyle: "single" | "double",
}

export type AstTypeTypeof = {
	tag: "typeof",
	typeof: Token<"typeof">,
	openParens: Token<"(">,
	expression: AstExpr,
	closeParens: Token<")">,
}

export type AstTypeGroup = {
	tag: "group",
	openParens: Token<"(">,
	type: AstType,
	closeParens: Token<">">,
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
	openBrace: Token<"{">,
	access: Token<"read" | "write">?,
	type: AstType,
	closeBrace: Token<"}">,
}

export type AstTypeTableItem = {
	kind: "indexer",
	access: Token<"read" | "write">?,
	indexerOpen: Token<"[">,
	key: AstType,
	indexerClose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
} | {
	kind: "stringproperty",
	access: Token<"read" | "write">?,
	indexerOpen: Token<"[">,
	key: AstTypeSingletonString,
	indexerClose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
} | {
	kind: "property",
	access: Token<"read" | "write">?,
	key: AstTypeSingletonString,
	indexerClose: Token<"]">,
	colon: Token<":">,
	value: AstType,
	separator: Token<"," | ";">?,
}

export type AstTypeTable = {
	tag: "table",
	openBrace: Token<"{">,
	entries: { AstTypeTableItem },
	closeBrace: Token<"}">,
}

export type AstTypeFunctionParameter = {
	name: Token?,
	colon: Token<":">?,
	type: AstType,
}

export type AstTypeFunction = {
	tag: "function",
	openGenerics: Token<"<">?,
	generics: Punctuated<AstGenericType>?,
	genericPacks: Punctuated<AstGenericTypePack>?,
	closeGenerics: Token<">">?,
	openParens: Token<"(">,
	parameters: Punctuated<AstTypeFunctionParameter>,
	vararg: AstTypePack?,
	closeParens: Token<")">,
	returnArrow: Token<"->">,
	returnTypes: AstTypePack,
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
	openParens: Token<"(">?,
	types: Punctuated<AstType>,
	tailType: AstTypePack?,
	closeParens: Token<")">?,
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

function luau.load(bytecode: Bytecode): () -> ...any
	error("not implemented")
end

return luau
