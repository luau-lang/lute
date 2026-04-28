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
--- A source location range, defined by begin and end line/column positions.
export type Span = setmetatable<SpanData, SpanMT>

luau.span = {}

--- Creates a `Span` from a table with `beginLine`, `beginColumn`, `endLine`, and `endColumn`.
function luau.span.create(tbl: { beginLine: number, beginColumn: number, endLine: number, endColumn: number }): Span
	error("not implemented")
end

--- A whitespace trivia token.
export type Whitespace = {
	read tag: "whitespace",
	read location: Span,
	read text: string,
}

--- A single-line comment trivia token (`--`).
export type SingleLineComment = {
	read tag: "comment",
	read location: Span,
	read text: string,
}

--- A multi-line block comment trivia token (`--[[...]]`).
export type MultiLineComment = {
	read tag: "blockcomment",
	read location: Span,
	read text: string,
	-- TODO: depth: number,
}

--- Trivia attached to a token: whitespace or comments.
export type Trivia = Whitespace | SingleLineComment | MultiLineComment

export type Token<Kind = string> = {
	read leadingTrivia: { Trivia },
	read location: Span,
	read text: Kind,
	read trailingTrivia: { Trivia },
	read kind: "token",
}

--- The end-of-file token.
export type Eof = Token<""> & { read tag: "eof" }

export type Pair<T, Separator> = { read node: T, read separator: Token<Separator>? }
export type Punctuated<T, Separator = ","> = { Pair<T, Separator> }

--- A local variable binding site in the AST.
export type AstLocal = {
	read location: Span,
	read kind: "local",
	read name: Token<string>,
	read colon: Token<":">?,
	read annotation: AstType?,
	read shadows: AstLocal?,
}

--- A parenthesized expression node.
export type AstExprGroup = {
	read location: Span,
	read kind: "expr",
	read tag: "group",
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}

--- A `nil` literal node.
export type AstExprConstantNil = {
	read location: Span,
	read kind: "expr",
	read tag: "nil",
	read token: Token<"nil">,
}

--- A boolean literal node (`true` or `false`).
export type AstExprConstantBool = {
	read location: Span,
	read kind: "expr",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}

--- A number literal node.
export type AstExprConstantNumber = {
	read location: Span,
	read kind: "expr",
	read tag: "number",
	read value: number,
	read token: Token<string>,
}

--- A string literal node.
export type AstExprConstantString = {
	read location: Span,
	read kind: "expr",
	read tag: "string",
	read quoteStyle: "single" | "double" | "block" | "interp",
	read blockDepth: number,
	read token: Token<string>,
}

--- A reference to a local variable.
export type AstExprLocal = {
	read location: Span,
	read kind: "expr",
	read tag: "local",
	read token: Token<string>,
	read ["local"]: AstLocal,
	read upvalue: boolean,
}

--- A reference to a global variable.
export type AstExprGlobal = { read location: Span, read kind: "expr", read tag: "global", read name: Token }

--- A varargs expression node (`...`).
export type AstExprVarargs = {
	read location: Span,
	read kind: "expr",
	read tag: "vararg",
	read token: Token<"...">,
}

--- A function call expression node.
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

--- An explicit generic instantiation expression node (e.g., `f<<T>>`).
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

--- A dot or colon index expression node (e.g., `t.k` or `t:method`).
export type AstExprIndexName = {
	read location: Span,
	read kind: "expr",
	read tag: "indexname",
	read expression: AstExpr,
	read accessor: Token<"." | ":">,
	read index: Token<string>,
	read indexLocation: Span,
}

--- A bracketed index expression node (e.g., `t[k]`).
export type AstExprIndexExpr = {
	read location: Span,
	read kind: "expr",
	read tag: "index",
	read expression: AstExpr,
	read openBrackets: Token<"[">,
	read index: AstExpr,
	read closeBrackets: Token<"]">,
}

--- An anonymous function expression node.
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
--- A positional table constructor entry (e.g., `value` in `{ value }`).
export type AstTableExprListItem = {
	read location: Span,
	read kind: "list",
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}

--- A named table constructor entry (e.g., `key = value`).
export type AstTableExprRecordItem = {
	read location: Span,
	read kind: "record",
	read key: Token<string>,
	read equals: Token<"=">,
	read value: AstExpr,
	read separator: Token<"," | ";">?,
	read isTableItem: true,
}

--- A table constructor entry with a computed key (e.g., `[expr] = value`).
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

--- Union of all table constructor entry types.
export type AstTableExprItem = AstTableExprListItem | AstTableExprRecordItem | AstTableExprGeneralItem

--- A table constructor expression node.
export type AstExprTable = {
	read location: Span,
	read kind: "expr",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableExprItem },
	read closeBrace: Token<"}">,
}

--- A unary expression node (e.g., `not x`, `-x`, `#x`).
export type AstExprUnary = {
	read location: Span,
	read kind: "expr",
	read tag: "unary",
	read operator: Token<"not" | "-" | "#">,
	read operand: AstExpr,
}

--- A binary expression node (e.g., `a + b`).
export type AstExprBinary = {
	read location: Span,
	read kind: "expr",
	read tag: "binary",
	read lhsOperand: AstExpr,
	read operator: Token,
	read rhsOperand: AstExpr,
}

--- An interpolated string expression node (e.g., `` `hello {name}` ``).
export type AstExprInterpString = {
	read location: Span,
	read kind: "expr",
	read tag: "interpolatedstring",
	read strings: { Token<string> },
	read expressions: { AstExpr },
}

--- A type assertion expression node (e.g., `x :: T`).
export type AstExprTypeAssertion = {
	read location: Span,
	read kind: "expr",
	read tag: "cast",
	read operand: AstExpr,
	read operator: Token<"::">,
	read annotation: AstType,
}

-- helper type for elseif clauses of an if-else expression, not actually an AstExpr itself
--- An `elseif` clause in an if-else expression.
export type AstElseIfExpr = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenExpr: AstExpr,
}

--- An if-else expression node.
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

--- Union of all expression node types in the Luau AST.
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

--- A block statement node (a sequence of statements).
export type AstStatBlock = {
	read location: Span,
	read kind: "stat",
	read tag: "block",
	read statements: { AstStat },
}

--- A `do...end` block statement node.
export type AstStatDo = {
	read location: Span,
	read kind: "stat",
	read tag: "do",
	read doKeyword: Token<"do">,
	read body: AstStatBlock,
	read endKeyword: Token<"end">,
}

--- An `elseif` clause in an if statement.
export type AstElseIfStat = {
	read elseIfKeyword: Token<"elseif">,
	read condition: AstExpr,
	read thenKeyword: Token<"then">,
	read thenBlock: AstStatBlock,
}

--- An `if...then...elseif...else...end` statement node.
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

--- A `while...do...end` loop statement node.
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

--- A `repeat...until` loop statement node.
export type AstStatRepeat = {
	read location: Span,
	read kind: "stat",
	read tag: "repeat",
	read repeatKeyword: Token<"repeat">,
	read body: AstStatBlock,
	read untilKeyword: Token<"until">,
	read condition: AstExpr,
}

--- A `break` statement node.
export type AstStatBreak = { read location: Span, read kind: "stat", read tag: "break", read token: Token<"break"> }

--- A `continue` statement node.
export type AstStatContinue = {
	read location: Span,
	read kind: "stat",
	read tag: "continue",
	read token: Token<"continue">,
}

--- A `return` statement node.
export type AstStatReturn = {
	read location: Span,
	read kind: "stat",
	read tag: "return",
	read returnKeyword: Token<"return">,
	read expressions: Punctuated<AstExpr>,
}

--- A statement consisting of a bare expression (e.g., a function call used as a statement).
export type AstStatExpr = {
	read location: Span,
	read kind: "stat",
	read tag: "expression",
	read expression: AstExpr,
}

--- A `local` variable declaration statement node.
export type AstStatLocal = {
	read location: Span,
	read kind: "stat",
	read tag: "local",
	read localKeyword: Token<"local">,
	read variables: Punctuated<AstLocal>,
	read equals: Token<"=">?,
	read values: Punctuated<AstExpr>,
}

--- A `const` variable declaration statement node.
export type AstStatConst = {
	read location: Span,
	read kind: "stat",
	read tag: "const",
	read constKeyword: Token<"const">,
	read variables: Punctuated<AstLocal>,
	read equals: Token<"=">?,
	read values: Punctuated<AstExpr>,
}

--- A numeric `for` loop statement node.
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

--- A generic `for...in` loop statement node.
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

--- An assignment statement node.
export type AstStatAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "assign",
	read variables: Punctuated<AstExpr>,
	read equals: Token<"=">,
	read values: Punctuated<AstExpr>,
}

--- A compound assignment statement node (e.g., `x += 1`).
export type AstStatCompoundAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "compoundassign",
	read variable: AstExpr,
	read operand: Token, -- TODO: Enforce token type
	read value: AstExpr,
}

--- A function attribute node (`@checked`, `@native`, or `@deprecated`).
export type AstAttribute = {
	read location: Span,
	read kind: "attribute",
	read token: Token<"@checked" | "@native" | "@deprecated">,
}

--- A function declaration statement node.
export type AstStatFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "function",
	read name: AstExpr,
	read func: AstExprFunction,
}

--- A `local function` declaration statement node.
export type AstStatLocalFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "localfunction",
	read localKeyword: Token<"local">,
	read name: AstLocal,
	read func: AstExprFunction,
}

--- A `type` alias declaration statement node.
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
--- A `type function` declaration statement node.
export type AstStatTypeFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "typefunction",
	read export: Token<"export">?,
	read type: Token<"type">,
	read name: Token,
	read body: AstExprFunction,
}

--- Union of all statement node types in the Luau AST.
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
	| AstStatConst
	| AstStatFor
	| AstStatForIn
	| AstStatAssign
	| AstStatCompoundAssign
	| AstStatFunction
	| AstStatLocalFunction
	| AstStatTypeAlias
	| AstStatTypeFunction

--- A generic type parameter (e.g., `T` in `function f<T>`).
export type AstGenericType = {
	read tag: "generic",
	read name: Token<string>,
	read equals: Token<"=">?,
	read default: AstType?,
}

--- A generic type pack parameter (e.g., `T...` in `function f<T...>`).
export type AstGenericTypePack = {
	read tag: "genericpack",
	read name: Token<string>,
	read ellipsis: Token<"...">,
	read equals: Token<"=">?,
	read default: AstTypePack?,
}

--- A named type reference node (e.g., `string`, `MyType<T>`).
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

--- A boolean singleton type node (`true` or `false`).
export type AstTypeSingletonBool = {
	read location: Span,
	read kind: "type",
	read tag: "boolean",
	read value: boolean,
	read token: Token<"true" | "false">,
}

--- A string singleton type node (e.g., `"hello"`).
export type AstTypeSingletonString = {
	read location: Span,
	read kind: "type",
	read tag: "string",
	read quoteStyle: "single" | "double",
	read token: Token<string>,
}

--- A `typeof(expr)` type annotation node.
export type AstTypeTypeof = {
	read location: Span,
	read kind: "type",
	read tag: "typeof",
	read typeof: Token<"typeof">,
	read openParens: Token<"(">,
	read expression: AstExpr,
	read closeParens: Token<")">,
}

--- A parenthesized type annotation node.
export type AstTypeGroup = {
	read location: Span,
	read kind: "type",
	read tag: "group",
	read openParens: Token<"(">,
	read type: AstType,
	read closeParens: Token<")">,
}

--- An optional type annotation node (e.g., `T?`).
export type AstTypeOptional = { read location: Span, read kind: "type", read tag: "optional", read token: Token<"?"> }

--- A union type annotation node (e.g., `A | B`).
export type AstTypeUnion = {
	read location: Span,
	read kind: "type",
	read tag: "union",
	read leading: Token<"|">?,
	-- Separator may be nil for AstTypeOptional
	read types: Punctuated<AstType, "|">,
}

--- An intersection type annotation node (e.g., `A & B`).
export type AstTypeIntersection = {
	read location: Span,
	read kind: "type",
	read tag: "intersection",
	read leading: Token<"&">?,
	read types: Punctuated<AstType, "&">,
}

--- An array type annotation node (e.g., `{ T }`).
export type AstTypeArray = {
	read location: Span,
	read kind: "type",
	read tag: "array",
	read openBrace: Token<"{">,
	read access: Token<"read" | "write">?,
	read type: AstType,
	read closeBrace: Token<"}">,
}

--- A computed-key indexer entry in a table type (e.g., `[K]: V`).
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

--- A string-literal-keyed property entry in a table type (e.g., `["key"]: T`).
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

--- A named property entry in a table type (e.g., `key: T`).
export type AstTableTypeItemProperty = {
	read kind: "property",
	read access: Token<"read" | "write">?,
	read key: Token,
	read colon: Token<":">,
	read value: AstType,
	read separator: Token<"," | ";">?,
}

--- Union of all table type entry kinds.
export type AstTableTypeItem = AstTableTypeItemIndexer | AstTableTypeItemStringProperty | AstTableTypeItemProperty

--- A table type annotation node.
export type AstTypeTable = {
	read location: Span,
	read kind: "type",
	read tag: "table",
	read openBrace: Token<"{">,
	read entries: { AstTableTypeItem },
	read closeBrace: Token<"}">,
}

--- A parameter in a function type annotation.
export type AstFunctionTypeParameter = {
	read location: Span,
	read name: Token?,
	read colon: Token<":">?,
	read type: AstType,
}

-- A type representing a Luau function
--- A function type annotation node.
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

--- Union of all type annotation node types in the Luau AST.
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

--- An explicit type pack annotation node (e.g., `(T, U)`).
export type AstTypePackExplicit = {
	read location: Span,
	read kind: "typepack",
	read tag: "explicit",
	read openParens: Token<"(">?,
	read types: Punctuated<AstType>,
	read tailType: AstTypePack?,
	read closeParens: Token<")">?,
}

--- A generic type pack annotation node (e.g., `T...`).
export type AstTypePackGeneric = {
	read location: Span,
	read kind: "typepack",
	read tag: "generic",
	read name: Token,
	read ellipsis: Token<"...">,
}

--- A variadic type pack annotation node (e.g., `...T`).
export type AstTypePackVariadic = {
	read location: Span,
	read kind: "typepack",
	read tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	read ellipsis: Token<"...">?,
	read type: AstType,
}

--- Union of all type pack annotation node types in the Luau AST.
export type AstTypePack = AstTypePackExplicit | AstTypePackGeneric | AstTypePackVariadic

--- Union of all node types in the Luau AST.
export type AstNode = AstExpr | AstStat | AstType | AstTypePack | AstLocal | AstAttribute | Token

--- The result of parsing a Luau script, containing the root block, EOF token, and source location info.
export type ParseResult = {
	read root: AstStatBlock,
	read eof: Eof,
	read lines: number,
	read lineOffsets: { number },
}

--- Parses `source` as a Luau script and returns the resulting AST.
function luau.parse(source: string): ParseResult
	error("not implemented")
end

--- Parses `source` as a single Luau expression and returns the resulting AST node.
function luau.parseExpr(source: string): AstExpr
	error("not implemented")
end

--- Compiled Luau bytecode produced by `luau.compile`.
export type Bytecode = { bytecode: string }

--- Compiles Luau `source` to bytecode.
function luau.compile(source: string): Bytecode
	error("not implemented")
end

--- Loads `bytecode` into a callable function. `chunkname` names the chunk for error messages. An optional `env` table can override the global environment.
function luau.load(bytecode: Bytecode, chunkname: string, env: { [any]: any }?): (...any) -> ...any
	error("not implemented")
end

--- Resolves the require path `path` relative to `fromchunkname`, returning the absolute path.
function luau.resolveModule(path: string, fromchunkname: string): string
	error("not implemented")
end

--- A resolved Luau type, as returned by `typeofModule`.
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

--- A resolved Luau type pack, as returned by `typeofModule`.
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

--- Returns the type pack representing the return types of the module at `modulepath`, or `nil` if unavailable.
function luau.typeofModule(modulepath: string): TypePack?
	error("not implemented")
end

return luau
