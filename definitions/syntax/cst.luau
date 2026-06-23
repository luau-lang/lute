-- lute-lint-global-ignore(unused_variable)
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

local span = {}

--- Creates a `Span` from a table with `beginLine`, `beginColumn`, `endLine`, and `endColumn`.
function span.create(tbl: { beginLine: number, beginColumn: number, endLine: number, endColumn: number }): Span
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

export type CstToken<Kind = string> = {
	read leadingTrivia: { Trivia },
	read location: Span,
	read text: Kind,
	read trailingTrivia: { Trivia },
	read kind: "token",
}

--- The end-of-file token.
export type CstEof = CstToken<""> & { read tag: "eof" }

type CstPunctuatedData<T, Separator = ","> = { read [number]: T, read separators: { CstToken<Separator> } }

-- __len not needed because # already returns number of array entries in table
type CstPunctuatedMT<T, Separator = ","> = {
	read __iter: (CstPunctuatedData<T, Separator>) -> (({ read [number]: T }, number?) -> (number?, T), { T }),
}

--- A punctuated sequence of items (e.g., function parameters, arguments, type parameters) with separators (e.g., commas).
--- The `__iter` metamethod modifies generalized iteration so that only nodes are iterated over
export type CstPunctuated<T, Separator = ","> = setmetatable<
	CstPunctuatedData<T, Separator>,
	CstPunctuatedMT<T, Separator>
>

--- A local variable binding site in the CST.
export type CstLocal = {
	read location: Span,
	read kind: "local",
	read name: CstToken<string>,
	read colon: CstToken<":">?,
	read annotation: CstType?,
	read shadows: CstLocal?,
}

--- A parenthesized expression node.
export type CstExprGroup = {
	read location: Span,
	read kind: "expr",
	read tag: "group",
	read openParens: CstToken<"(">,
	read expression: CstExpr,
	read closeParens: CstToken<")">,
}

--- A `nil` literal node.
export type CstExprConstantNil = {
	read location: Span,
	read kind: "expr",
	read tag: "nil",
	read token: CstToken<"nil">,
}

--- A boolean literal node (`true` or `false`).
export type CstExprConstantBool = {
	read location: Span,
	read kind: "expr",
	read tag: "boolean",
	read value: boolean,
	read token: CstToken<"true" | "false">,
}

--- A number literal node.
export type CstExprConstantNumber = {
	read location: Span,
	read kind: "expr",
	read tag: "number",
	read value: number,
	read token: CstToken<string>,
}

--- An integer literal node.
export type CstExprConstantInteger = {
	read location: Span,
	read kind: "expr",
	read tag: "integer",
	read value: number,
	read token: CstToken<string>,
}

--- A string literal node.
export type CstExprConstantString = {
	read location: Span,
	read kind: "expr",
	read tag: "string",
	read quoteStyle: "single" | "double" | "block" | "interp",
	read blockDepth: number,
	read value: CstToken<string>,
}

--- A reference to a local variable.
export type CstExprLocal = {
	read location: Span,
	read kind: "expr",
	read tag: "local",
	read token: CstToken<string>,
	read ["local"]: CstLocal,
	read upvalue: boolean,
}

--- A reference to a global variable.
export type CstExprGlobal = { read location: Span, read kind: "expr", read tag: "global", read name: CstToken }

--- A varargs expression node (`...`).
export type CstExprVarargs = {
	read location: Span,
	read kind: "expr",
	read tag: "vararg",
	read token: CstToken<"...">,
}

--- A function call expression node.
export type CstExprCall = {
	read location: Span,
	read kind: "expr",
	read tag: "call",
	read func: CstExpr,
	read openParens: CstToken<"(">?,
	read arguments: CstPunctuated<CstExpr>,
	read closeParens: CstToken<")">?,
	read self: boolean,
	read argLocation: Span,
}

--- An explicit generic instantiation expression node (e.g., `f<<T>>`).
export type CstExprInstantiate = {
	read location: Span,
	read kind: "expr",
	read tag: "instantiate",
	read expr: CstExpr,
	read leftArrow1: CstToken<"<">,
	read leftArrow2: CstToken<"<">,
	read typeArguments: CstPunctuated<CstType | CstTypePack>,
	read rightArrow1: CstToken<">">,
	read rightArrow2: CstToken<">">,
}

--- A dot or colon index expression node (e.g., `t.k` or `t:method`).
export type CstExprIndexName = {
	read location: Span,
	read kind: "expr",
	read tag: "indexname",
	read expression: CstExpr,
	read accessor: CstToken<"." | ":">,
	read index: CstToken<string>,
	read indexLocation: Span,
}

--- A bracketed index expression node (e.g., `t[k]`).
export type CstExprIndexExpr = {
	read location: Span,
	read kind: "expr",
	read tag: "index",
	read expression: CstExpr,
	read openBrackets: CstToken<"[">,
	read index: CstExpr,
	read closeBrackets: CstToken<"]">,
}

--- An anonymous function expression node.
export type CstExprFunction = {
	read location: Span,
	read kind: "expr",
	read tag: "function",
	read attributes: { CstAttribute },
	read functionKeyword: CstToken<"function">,
	read openGenerics: CstToken<"<">?,
	read generics: CstPunctuated<CstGenericType>,
	read genericPacks: CstPunctuated<CstGenericTypePack>,
	read closeGenerics: CstToken<">">?,
	read openParens: CstToken<"(">,
	read self: CstLocal?,
	read parameters: CstPunctuated<CstLocal>,
	read hasVararg: boolean, -- Present so AstExprFunction subtypes structurally against CstExprFunction
	read vararg: CstToken<"...">?,
	read varargColon: CstToken<":">?,
	read varargAnnotation: CstTypePack?,
	read closeParens: CstToken<")">,
	read returnSpecifier: CstToken<":">?,
	read returnAnnotation: CstTypePack?,
	read body: CstStatBlock,
	read endKeyword: CstToken<"end">,
}

-- helper types for items contained in an CstExprTable, not actually CstExprs themselves
--- A positional table constructor entry (e.g., `value` in `{ value }`).
export type CstTableExprListItem = {
	read location: Span,
	read kind: "list",
	read value: CstExpr,
	read separator: CstToken<"," | ";">?,
	read isTableItem: true,
}

--- A named table constructor entry (e.g., `key = value`).
export type CstTableExprRecordItem = {
	read location: Span,
	read kind: "record",
	read key: CstToken<string>,
	read equals: CstToken<"=">,
	read value: CstExpr,
	read separator: CstToken<"," | ";">?,
	read isTableItem: true,
}

--- A table constructor entry with a computed key (e.g., `[expr] = value`).
export type CstTableExprGeneralItem = {
	read location: Span,
	read kind: "general",
	read indexerOpen: CstToken<"[">,
	read key: CstExpr,
	read indexerClose: CstToken<"]">,
	read equals: CstToken<"=">,
	read value: CstExpr,
	read separator: CstToken<"," | ";">?,
	read isTableItem: true,
}

--- Union of all table constructor entry types.
export type CstTableExprItem = CstTableExprListItem | CstTableExprRecordItem | CstTableExprGeneralItem

--- A table constructor expression node.
export type CstExprTable = {
	read location: Span,
	read kind: "expr",
	read tag: "table",
	read openBrace: CstToken<"{">,
	read entries: { CstTableExprItem },
	read closeBrace: CstToken<"}">,
}

--- A unary expression node (e.g., `not x`, `-x`, `#x`).
export type CstExprUnary = {
	read location: Span,
	read kind: "expr",
	read tag: "unary",
	read operator: CstToken<"not" | "-" | "#">,
	read operand: CstExpr,
}

--- A binary expression node (e.g., `a + b`).
export type CstExprBinary = {
	read location: Span,
	read kind: "expr",
	read tag: "binary",
	read lhsOperand: CstExpr,
	read operator: CstToken,
	read rhsOperand: CstExpr,
}

--- An interpolated string expression node (e.g., `` `hello {name}` ``).
export type CstExprInterpString = {
	read location: Span,
	read kind: "expr",
	read tag: "interpolatedstring",
	read strings: { CstToken<string> },
	read expressions: { CstExpr },
}

--- A type assertion expression node (e.g., `x :: T`).
export type CstExprTypeAssertion = {
	read location: Span,
	read kind: "expr",
	read tag: "cast",
	read operand: CstExpr,
	read operator: CstToken<"::">,
	read annotation: CstType,
}

-- helper type for elseif clauses of an if-else expression, not actually an CstExpr itself
--- An `elseif` clause in an if-else expression.
export type CstElseIfExpr = {
	read elseIfKeyword: CstToken<"elseif">,
	read condition: CstExpr,
	read thenKeyword: CstToken<"then">,
	read thenExpr: CstExpr,
}

--- An if-else expression node.
export type CstExprIfElse = {
	read location: Span,
	read kind: "expr",
	read tag: "conditional",
	read ifKeyword: CstToken<"if">,
	read condition: CstExpr,
	read thenKeyword: CstToken<"then">,
	read thenExpr: CstExpr,
	read elseifs: { CstElseIfExpr },
	read elseKeyword: CstToken<"else">,
	read elseExpr: CstExpr,
}

--- Union of all expression node types in the Luau CST.
export type CstExpr =
	| CstExprGroup
	| CstExprConstantNil
	| CstExprConstantBool
	| CstExprConstantNumber
	| CstExprConstantInteger
	| CstExprConstantString
	| CstExprLocal
	| CstExprGlobal
	| CstExprVarargs
	| CstExprCall
	| CstExprInstantiate
	| CstExprIndexName
	| CstExprIndexExpr
	| CstExprFunction
	| CstExprTable
	| CstExprUnary
	| CstExprBinary
	| CstExprInterpString
	| CstExprTypeAssertion
	| CstExprIfElse

--- A block statement node (a sequence of statements).
export type CstStatBlock = {
	read location: Span,
	read kind: "stat",
	read tag: "block",
	read statements: { CstStat },
}

--- A `do...end` block statement node.
export type CstStatDo = {
	read location: Span,
	read kind: "stat",
	read tag: "do",
	read doKeyword: CstToken<"do">,
	read body: CstStatBlock,
	read endKeyword: CstToken<"end">,
}

--- An `elseif` clause in an if statement.
export type CstElseIfStat = {
	read elseIfKeyword: CstToken<"elseif">,
	read condition: CstExpr,
	read thenKeyword: CstToken<"then">,
	read thenBlock: CstStatBlock,
}

--- An `if...then...elseif...else...end` statement node.
export type CstStatIf = {
	read location: Span,
	read kind: "stat",
	read tag: "conditional",
	read ifKeyword: CstToken<"if">,
	read condition: CstExpr,
	read thenKeyword: CstToken<"then">,
	read thenBlock: CstStatBlock,
	read elseifs: { CstElseIfStat },
	read elseKeyword: CstToken<"else">?, -- TODO: This could be elseif!
	read elseBlock: CstStatBlock?,
	read endKeyword: CstToken<"end">,
}

--- A `while...do...end` loop statement node.
export type CstStatWhile = {
	read location: Span,
	read kind: "stat",
	read tag: "while",
	read whileKeyword: CstToken<"while">,
	read condition: CstExpr,
	read doKeyword: CstToken<"do">,
	read body: CstStatBlock,
	read endKeyword: CstToken<"end">,
}

--- A `repeat...until` loop statement node.
export type CstStatRepeat = {
	read location: Span,
	read kind: "stat",
	read tag: "repeat",
	read repeatKeyword: CstToken<"repeat">,
	read body: CstStatBlock,
	read untilKeyword: CstToken<"until">,
	read condition: CstExpr,
}

--- A `break` statement node.
export type CstStatBreak = { read location: Span, read kind: "stat", read tag: "break", read token: CstToken<"break"> }

--- A `continue` statement node.
export type CstStatContinue = {
	read location: Span,
	read kind: "stat",
	read tag: "continue",
	read token: CstToken<"continue">,
}

--- A `return` statement node.
export type CstStatReturn = {
	read location: Span,
	read kind: "stat",
	read tag: "return",
	read returnKeyword: CstToken<"return">,
	read expressions: CstPunctuated<CstExpr>,
}

--- A statement consisting of a bare expression (e.g., a function call used as a statement).
export type CstStatExpr = {
	read location: Span,
	read kind: "stat",
	read tag: "expression",
	read expression: CstExpr,
}

--- A `local` variable declaration statement node.
export type CstStatLocal = {
	read location: Span,
	read kind: "stat",
	read tag: "local",
	read localKeyword: CstToken<"local">,
	read variables: CstPunctuated<CstLocal>,
	read equals: CstToken<"=">?,
	read values: CstPunctuated<CstExpr>,
}

--- A `const` variable declaration statement node.
export type CstStatConst = {
	read location: Span,
	read kind: "stat",
	read tag: "const",
	read constKeyword: CstToken<"const">,
	read variables: CstPunctuated<CstLocal>,
	read equals: CstToken<"=">?,
	read values: CstPunctuated<CstExpr>,
}

--- A numeric `for` loop statement node.
export type CstStatFor = {
	read location: Span,
	read kind: "stat",
	read tag: "for",
	read forKeyword: CstToken<"for">,
	read variable: CstLocal,
	read equals: CstToken<"=">,
	read from: CstExpr,
	read toComma: CstToken<",">,
	read to: CstExpr,
	read stepComma: CstToken<",">?,
	read step: CstExpr?,
	read doKeyword: CstToken<"do">,
	read body: CstStatBlock,
	read endKeyword: CstToken<"end">,
}

--- A generic `for...in` loop statement node.
export type CstStatForIn = {
	read location: Span,
	read kind: "stat",
	read tag: "forin",
	read forKeyword: CstToken<"for">,
	read variables: CstPunctuated<CstLocal>,
	read inKeyword: CstToken<"in">,
	read values: CstPunctuated<CstExpr>,
	read doKeyword: CstToken<"do">,
	read body: CstStatBlock,
	read endKeyword: CstToken<"end">,
}

--- An assignment statement node.
export type CstStatAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "assign",
	read variables: CstPunctuated<CstExpr>,
	read equals: CstToken<"=">,
	read values: CstPunctuated<CstExpr>,
}

--- A compound assignment statement node (e.g., `x += 1`).
export type CstStatCompoundAssign = {
	read location: Span,
	read kind: "stat",
	read tag: "compoundassign",
	read variable: CstExpr,
	read operator: CstToken, -- TODO: Enforce token type
	read value: CstExpr,
}

--- A function attribute node (`@checked`, `@native`, or `@deprecated`).
export type CstAttribute = {
	read location: Span,
	read kind: "attribute",
	read name: CstToken<"@checked" | "@native" | "@deprecated">,
}

--- A function declaration statement node.
export type CstStatFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "function",
	read name: CstExpr,
	read func: CstExprFunction,
}

--- A `local function` declaration statement node.
export type CstStatLocalFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "localfunction",
	read localKeyword: CstToken<"local">,
	read name: CstLocal,
	read func: CstExprFunction,
}

--- A `type` alias declaration statement node.
export type CstStatTypeAlias = {
	read location: Span,
	read kind: "stat",
	read tag: "typealias",
	read isExported: boolean,
	read export: CstToken<"export">?,
	read typeToken: CstToken<"type">,
	read name: CstToken,
	read openGenerics: CstToken<"<">?,
	read generics: CstPunctuated<CstGenericType>?,
	read genericPacks: CstPunctuated<CstGenericTypePack>?,
	read closeGenerics: CstToken<">">?,
	read equals: CstToken<"=">,
	read type: CstType,
}

-- A type function
--- A `type function` declaration statement node.
export type CstStatTypeFunction = {
	read location: Span,
	read kind: "stat",
	read tag: "typefunction",
	read isExported: boolean,
	read export: CstToken<"export">?,
	read type: CstToken<"type">,
	read name: CstToken,
	read body: CstExprFunction,
}

--- Union of all statement node types in the Luau CST.
export type CstStat =
	| CstStatBlock
	| CstStatDo
	| CstStatIf
	| CstStatWhile
	| CstStatRepeat
	| CstStatBreak
	| CstStatContinue
	| CstStatReturn
	| CstStatExpr
	| CstStatLocal
	| CstStatConst
	| CstStatFor
	| CstStatForIn
	| CstStatAssign
	| CstStatCompoundAssign
	| CstStatFunction
	| CstStatLocalFunction
	| CstStatTypeAlias
	| CstStatTypeFunction

--- A generic type parameter (e.g., `T` in `function f<T>`).
export type CstGenericType = {
	read tag: "generic",
	read name: CstToken<string>,
	read equals: CstToken<"=">?,
	read default: CstType?,
}

--- A generic type pack parameter (e.g., `T...` in `function f<T...>`).
export type CstGenericTypePack = {
	read tag: "genericpack",
	read name: CstToken<string>,
	read ellipsis: CstToken<"...">,
	read equals: CstToken<"=">?,
	read default: CstTypePack?,
}

--- A named type reference node (e.g., `string`, `MyType<T>`).
export type CstTypeReference = {
	read location: Span,
	read kind: "type",
	read tag: "reference",
	read prefix: CstToken<string>?,
	read prefixPoint: CstToken<".">?,
	read name: CstToken<string>,
	read openParameters: CstToken<"<">?,
	read parameters: CstPunctuated<CstType | CstTypePack>?,
	read closeParameters: CstToken<">">?,
}

--- A boolean singleton type node (`true` or `false`).
export type CstTypeSingletonBool = {
	read location: Span,
	read kind: "type",
	read tag: "boolean",
	read value: boolean,
	read token: CstToken<"true" | "false">,
}

--- A string singleton type node (e.g., `"hello"`).
export type CstTypeSingletonString = {
	read location: Span,
	read kind: "type",
	read tag: "string",
	read quoteStyle: "single" | "double",
	read value: CstToken<string>,
}

--- A `typeof(expr)` type annotation node.
export type CstTypeTypeof = {
	read location: Span,
	read kind: "type",
	read tag: "typeof",
	read typeof: CstToken<"typeof">,
	read openParens: CstToken<"(">,
	read expression: CstExpr,
	read closeParens: CstToken<")">,
}

--- A parenthesized type annotation node.
export type CstTypeGroup = {
	read location: Span,
	read kind: "type",
	read tag: "group",
	read openParens: CstToken<"(">,
	read type: CstType,
	read closeParens: CstToken<")">,
}

--- An optional type annotation node (e.g., `T?`).
export type CstTypeOptional =
	{ read location: Span, read kind: "type", read tag: "optional", read token: CstToken<"?"> }

--- A union type annotation node (e.g., `A | B`).
export type CstTypeUnion = {
	read location: Span,
	read kind: "type",
	read tag: "union",
	read leading: CstToken<"|">?,
	-- Separator may be nil for CstTypeOptional
	read types: CstPunctuated<CstType, "|">,
}

--- An intersection type annotation node (e.g., `A & B`).
export type CstTypeIntersection = {
	read location: Span,
	read kind: "type",
	read tag: "intersection",
	read leading: CstToken<"&">?,
	read types: CstPunctuated<CstType, "&">,
}

--- An array type annotation node (e.g., `{ T }`).
export type CstTypeArray = {
	read location: Span,
	read kind: "type",
	read tag: "array",
	read openBrace: CstToken<"{">,
	read access: CstToken<"read" | "write">?,
	read type: CstType,
	read closeBrace: CstToken<"}">,
}

--- A computed-key indexer entry in a table type (e.g., `[K]: V`).
export type CstTableTypeItemIndexer = {
	read kind: "indexer",
	read access: CstToken<"read" | "write">?,
	read indexerOpen: CstToken<"[">,
	read key: CstType,
	read indexerClose: CstToken<"]">,
	read colon: CstToken<":">,
	read value: CstType,
	read separator: CstToken<"," | ";">?,
}

--- A string-literal-keyed property entry in a table type (e.g., `["key"]: T`).
export type CstTableTypeItemStringProperty = {
	read kind: "stringproperty",
	read access: CstToken<"read" | "write">?,
	read indexerOpen: CstToken<"[">,
	read key: CstTypeSingletonString,
	read indexerClose: CstToken<"]">,
	read colon: CstToken<":">,
	read value: CstType,
	read separator: CstToken<"," | ";">?,
}

--- A named property entry in a table type (e.g., `key: T`).
export type CstTableTypeItemProperty = {
	read kind: "property",
	read access: CstToken<"read" | "write">?,
	read key: CstToken,
	read colon: CstToken<":">,
	read value: CstType,
	read separator: CstToken<"," | ";">?,
}

--- Union of all table type entry kinds.
export type CstTableTypeItem = CstTableTypeItemIndexer | CstTableTypeItemStringProperty | CstTableTypeItemProperty

--- A table type annotation node.
export type CstTypeTable = {
	read location: Span,
	read kind: "type",
	read tag: "table",
	read openBrace: CstToken<"{">,
	read entries: { CstTableTypeItem },
	read closeBrace: CstToken<"}">,
}

--- A parameter in a function type annotation.
export type CstFunctionTypeParameter = {
	read name: CstToken?,
	read colon: CstToken<":">?,
	read type: CstType,
}

-- A type representing a Luau function
--- A function type annotation node.
export type CstTypeFunction = {
	read location: Span,
	read kind: "type",
	read tag: "function",
	read openGenerics: CstToken<"<">?,
	read generics: CstPunctuated<CstGenericType>?,
	read genericPacks: CstPunctuated<CstGenericTypePack>?,
	read closeGenerics: CstToken<">">?,
	read openParens: CstToken<"(">,
	read parameters: CstPunctuated<CstFunctionTypeParameter>,
	read vararg: CstTypePack?,
	read closeParens: CstToken<")">,
	read returnArrow: CstToken<"->">,
	read returnTypes: CstTypePack,
}

--- Union of all type annotation node types in the Luau CST.
export type CstType =
	| CstTypeReference
	| CstTypeSingletonBool
	| CstTypeSingletonString
	| CstTypeTypeof
	| CstTypeGroup
	| CstTypeUnion
	| CstTypeIntersection
	| CstTypeOptional
	| CstTypeArray
	| CstTypeTable
	| CstTypeFunction

--- An explicit type pack annotation node (e.g., `(T, U)`).
export type CstTypePackExplicit = {
	read location: Span,
	read kind: "typepack",
	read tag: "explicit",
	read openParens: CstToken<"(">?,
	read types: CstPunctuated<CstType>,
	read tailType: CstTypePack?,
	read closeParens: CstToken<")">?,
}

--- A generic type pack annotation node (e.g., `T...`).
export type CstTypePackGeneric = {
	read location: Span,
	read kind: "typepack",
	read tag: "generic",
	read name: CstToken,
	read ellipsis: CstToken<"...">,
}

--- A variadic type pack annotation node (e.g., `...T`).
export type CstTypePackVariadic = {
	read location: Span,
	read kind: "typepack",
	read tag: "variadic",
	--- May be nil when present as the vararg annotation in a function body
	read ellipsis: CstToken<"...">?,
	read type: CstType,
}

--- Union of all type pack annotation node types in the Luau CST.
export type CstTypePack = CstTypePackExplicit | CstTypePackGeneric | CstTypePackVariadic

--- Union of all node types in the Luau CST.
export type CstNode = CstExpr | CstStat | CstType | CstTypePack | CstLocal | CstAttribute | CstToken

--- The result of parsing a Luau script, containing the root block, EOF token, and source location info.
export type CstParseResult = {
	read root: CstStatBlock,
	read eof: CstEof,
	read lines: number,
	read lineOffsets: { number },
}

return { span = table.freeze(span) }
