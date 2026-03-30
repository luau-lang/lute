local fs = require("@std/fs")
local path = require("@std/path")
local strext = require("@std/stringext")
local test = require("@std/test")
local testTypes = require("@std/test/types")
local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")

local function assertEqualsLocation(
	assert: testTypes.Asserts,
	actual: syntax.Span,
	startLine: number,
	startColumn: number,
	endLine: number,
	endColumn: number
)
	assert.eq(actual.beginLine, startLine)
	assert.eq(actual.beginColumn, startColumn)
	assert.eq(actual.endLine, endLine)
	assert.eq(actual.endColumn, endColumn)
end

test.suite("Parser", function(suite)
	suite:case("tokenContainsLeadingSpaces", function(assert)
		local block = parser.parseblock("  local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.AstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 1)
		assert.eq(token.leadingTrivia[1].tag, "whitespace")
		assert.eq(token.leadingTrivia[1].text, "  ")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 1, 3)
	end)

	suite:case("tokenContainsLeadingNewline", function(assert)
		local block = parser.parseblock("\n" .. "local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.AstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 1)
		assert.eq(token.leadingTrivia[1].tag, "whitespace")
		assert.eq(token.leadingTrivia[1].text, "\n")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 2, 1)
	end)

	suite:case("tokenContainsLeadingSingleLineComment", function(assert)
		local block = parser.parseblock("-- comment\n" .. "local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.AstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 2)
		assert.eq(token.leadingTrivia[1].tag, "comment")
		assert.eq(token.leadingTrivia[1].text, "-- comment")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 1, 11)
		assert.eq(token.leadingTrivia[2].tag, "whitespace")
		assert.eq(token.leadingTrivia[2].text, "\n")
		assertEqualsLocation(assert, token.leadingTrivia[2].location, 1, 11, 2, 1)
	end)

	suite:case("tokenContainsLeadingBlockComment", function(assert)
		local block = parser.parseblock("--[[ comment ]] local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.AstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 2)
		assert.eq(token.leadingTrivia[1].tag, "blockcomment")
		assert.eq(token.leadingTrivia[1].text, "--[[ comment ]]")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 1, 16)
		assert.eq(token.leadingTrivia[2].tag, "whitespace")
		assert.eq(token.leadingTrivia[2].text, " ")
		assertEqualsLocation(assert, token.leadingTrivia[2].location, 1, 16, 1, 17)
	end)

	suite:case("tokenizeWhitespace", function(assert)
		local block = parser.parseblock("  \n\t\t\n\n" .. "local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.AstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 3)
		assert.eq(token.leadingTrivia[1].text, "  \n")
		assert.eq(token.leadingTrivia[2].text, "\t\t\n")
		assert.eq(token.leadingTrivia[3].text, "\n")
	end)

	suite:case("triviaSplitBetweenLeadingAndTrailing", function(assert)
		local block = parser.parseblock("local x = 'test' -- comment\n" .. "-- comment 2\nlocal y = 'value'")
		assert.eq(#block.statements, 2)

		local firstStmt = block.statements[1]
		assert.eq(firstStmt.tag, "local")

		local trailingToken: syntax.AstExpr = (firstStmt :: syntax.AstStatLocal).values[1].node
		assert.eq(trailingToken.tag, "string")
		local expr = trailingToken :: syntax.AstExprConstantString
		assert.eq(#expr.token.trailingTrivia, 3)
		assert.eq(expr.token.trailingTrivia[1].text, " ")
		assert.eq(expr.token.trailingTrivia[2].text, "-- comment")
		assert.eq(expr.token.trailingTrivia[3].text, "\n")

		local secondStmt = block.statements[2]
		assert.eq(secondStmt.tag, "local")

		local leadingToken = (secondStmt :: syntax.AstStatLocal).localKeyword
		assert.eq(#leadingToken.leadingTrivia, 2)
		assert.eq(leadingToken.leadingTrivia[1].text, "-- comment 2")
		assert.eq(leadingToken.leadingTrivia[2].text, "\n")
	end)

	local function visitDirectory(directory: string)
		for _, entry in fs.listdirectory(directory) do
			if entry.type ~= "file" then
				continue
			end
			if not strext.hassuffix(entry.name, ".luau") then
				continue
			end

			suite:case(`roundtrippable_Ast_{entry.name}`, function(assert)
				local p = path.join(directory, entry.name)
				local source = fs.readfiletostring(path.format(p))
				local result = printer.printfile(parser.parse(source))

				assert.eq(source, result)
			end)
		end
	end

	visitDirectory("examples")
	visitDirectory("tests/parserExamples")

	suite:case("lineOffsetsField", function(assert)
		local singleLineCode = "local x = 1"
		local result = parser.parse(singleLineCode)

		assert.eq(type(result.lineoffsets), "table")
		assert.eq(#result.lineoffsets, 1)
		assert.eq(result.lineoffsets[1], 1)

		local multiLineCode = "local x = 1\nlocal y = 2\nlocal z = 3"
		local multiResult = parser.parse(multiLineCode)

		assert.eq(type(multiResult.lineoffsets), "table")
		assert.eq(#multiResult.lineoffsets, 3)
		assert.eq(multiResult.lineoffsets[1], 1)
		assert.eq(multiResult.lineoffsets[2], 13)
		assert.eq(multiResult.lineoffsets[3], 25)

		local emptyLineCode = "local x = 1\n\nlocal y = 2"
		local emptyResult = parser.parse(emptyLineCode)

		assert.eq(type(emptyResult.lineoffsets), "table")
		assert.eq(#emptyResult.lineoffsets, 3)
		assert.eq(emptyResult.lineoffsets[1], 1)
		assert.eq(emptyResult.lineoffsets[2], 13)
		assert.eq(emptyResult.lineoffsets[3], 14)
	end)

	suite:case("canParseAttributes", function(assert)
		local code = [[
			@checked
			local function foo()
			end
		]]
		local subcases = {
			{ attr = "@checked", code = code },
			{ attr = "@native", code = code:gsub("checked", "native") },
			{ attr = "@deprecated", code = code:gsub("checked", "deprecated") },
		}

		for _, subcase in subcases do
			local block = parser.parseblock(subcase.code)
			assert.eq(#block.statements, 1)

			local l = block.statements[1]
			assert.eq(l.tag, "localfunction")

			local lf = l :: syntax.AstStatLocalFunction
			assert.eq(lf.func.attributes[1].token.text, subcase.attr)
		end
	end)
end)

test.suite("parseExpr", function(suite)
	suite:case("parseExprGroup", function(assert)
		local groupExpr = parser.parseexpr("(x)")
		assert.eq(groupExpr.tag, "group")
		assert.eq(groupExpr.kind, "expr")
		local expr = groupExpr :: syntax.AstExprGroup
		assert.eq(expr.openparens.text, "(")
		assert.eq(expr.closeparens.text, ")")
		assert.eq(expr.expression.tag, "global")
	end)

	suite:case("parseExprNil", function(assert)
		local expr = parser.parseexpr("nil")
		assert.eq(expr.tag, "nil")
		assert.eq(expr.kind, "expr")
		assert.eq((expr :: syntax.AstExprConstantNil).token.text, "nil")
	end)

	suite:case("parseExprBoolean", function(assert)
		local trueExpr = parser.parseexpr("true")
		assert.eq(trueExpr.tag, "boolean")
		assert.eq(trueExpr.kind, "expr")
		assert.eq((trueExpr :: syntax.AstExprConstantBool).token.text, "true")
		assert.that((trueExpr :: syntax.AstExprConstantBool).value)

		local falseExpr = parser.parseexpr("false")
		assert.eq(falseExpr.tag, "boolean")
		assert.eq(falseExpr.kind, "expr")
		assert.eq((falseExpr :: syntax.AstExprConstantBool).token.text, "false")
		assert.eq((falseExpr :: syntax.AstExprConstantBool).value, false)
	end)

	suite:case("parseExprNumber", function(assert)
		local numberExpr = parser.parseexpr("42")
		assert.eq(numberExpr.tag, "number")
		assert.eq(numberExpr.kind, "expr")
		assert.eq((numberExpr :: syntax.AstExprConstantNumber).token.text, "42")
		assert.eq((numberExpr :: syntax.AstExprConstantNumber).value, 42)

		local floatExpr = parser.parseexpr("3.14")
		assert.eq(floatExpr.tag, "number")
		assert.eq(floatExpr.kind, "expr")
		assert.eq((floatExpr :: syntax.AstExprConstantNumber).token.text, "3.14")
		assert.eq((floatExpr :: syntax.AstExprConstantNumber).value, 3.14)
	end)

	suite:case("parseExprString", function(assert)
		local singleQuoteExpr = parser.parseexpr("'hello'")
		assert.eq(singleQuoteExpr.tag, "string")
		assert.eq(singleQuoteExpr.kind, "expr")
		assert.eq((singleQuoteExpr :: syntax.AstExprConstantString).token.text, "hello")
		assert.eq((singleQuoteExpr :: syntax.AstExprConstantString).quotestyle, "single")

		local doubleQuoteExpr = parser.parseexpr('"world"')
		assert.eq(doubleQuoteExpr.tag, "string")
		assert.eq(doubleQuoteExpr.kind, "expr")
		assert.eq((doubleQuoteExpr :: syntax.AstExprConstantString).token.text, "world")
		assert.eq((doubleQuoteExpr :: syntax.AstExprConstantString).quotestyle, "double")

		local blockQuoteExpr = parser.parseexpr("[[world]]")
		assert.eq(blockQuoteExpr.tag, "string")
		assert.eq(blockQuoteExpr.kind, "expr")
		assert.eq((blockQuoteExpr :: syntax.AstExprConstantString).token.text, "world")
		assert.eq((blockQuoteExpr :: syntax.AstExprConstantString).quotestyle, "block")

		local interpExpr = parser.parseexpr("`foobar`")
		assert.eq(interpExpr.tag, "string")
		assert.eq(interpExpr.kind, "expr")
		assert.eq((interpExpr :: syntax.AstExprConstantString).token.text, "foobar")
		assert.eq((interpExpr :: syntax.AstExprConstantString).quotestyle, "interp")
	end)

	suite:case("parseExprLocal", function(assert)
		local localExpr = parser.parseexpr("x")
		assert.eq(localExpr.tag, "global")
		assert.eq(localExpr.kind, "expr")
		assert.eq((localExpr :: syntax.AstExprGlobal).name.text, "x")
	end)

	suite:case("parseExprGlobal", function(assert)
		local globalExpr = parser.parseexpr("_G")
		assert.eq(globalExpr.tag, "global")
		assert.eq(globalExpr.kind, "expr")
		assert.eq((globalExpr :: syntax.AstExprGlobal).name.text, "_G")
	end)

	suite:case("parseExprVarargs", function(assert)
		local varargsExpr = parser.parseexpr("...")
		assert.eq(varargsExpr.tag, "vararg")
		assert.eq(varargsExpr.kind, "expr")
		assert.eq((varargsExpr :: syntax.AstExprVarargs).token.text, "...")
	end)

	suite:case("parseExprCall", function(assert)
		local callExpr = parser.parseexpr("foo()")
		assert.eq(callExpr.tag, "call")
		assert.eq(callExpr.kind, "expr")
		assert.eq((callExpr :: syntax.AstExprCall).func.tag, "global")
		assert.eq(((callExpr :: syntax.AstExprCall).func :: syntax.AstExprGlobal).name.text, "foo")
		assert.eq((callExpr :: syntax.AstExprCall).self, false)
		assert.eq(#(callExpr :: syntax.AstExprCall).arguments, 0)

		local callWithArgsExpr = parser.parseexpr("bar(1, 2)")
		assert.eq(callWithArgsExpr.tag, "call")
		assert.eq(callWithArgsExpr.kind, "expr")
		assert.eq(#(callWithArgsExpr :: syntax.AstExprCall).arguments, 2)
		assert.eq((callWithArgsExpr :: syntax.AstExprCall).arguments[1].node.tag, "number")
		assert.eq((callWithArgsExpr :: syntax.AstExprCall).arguments[2].node.tag, "number")
	end)

	suite:case("parseExprInstantiate", function(assert)
		local callExpr = parser.parseexpr("foo<<string, ...number>>()")
		assert.eq(callExpr.kind, "expr")
		assert.eq(callExpr.tag, "call")

		local instExpr = (callExpr :: syntax.AstExprCall).func
		assert.eq(instExpr.tag, "instantiate")
		assert.eq(instExpr.kind, "expr")
		assert.eq((instExpr :: syntax.AstExprInstantiate).expr.tag, "global")
		assert.eq((instExpr :: syntax.AstExprInstantiate).leftarrow1.text, "<")
		assert.eq((instExpr :: syntax.AstExprInstantiate).leftarrow2.text, "<")
		assert.eq(#(instExpr :: syntax.AstExprInstantiate).typearguments, 2)
		assert.eq(((instExpr :: syntax.AstExprInstantiate).typearguments[1].node).kind, "type")
		assert.eq(((instExpr :: syntax.AstExprInstantiate).typearguments[1].node).tag, "reference")
		assert.eq(((instExpr :: syntax.AstExprInstantiate).typearguments[2].node).kind, "typepack")
		assert.eq(((instExpr :: syntax.AstExprInstantiate).typearguments[2].node).tag, "variadic")
		assert.eq((instExpr :: syntax.AstExprInstantiate).rightarrow1.text, ">")
		assert.eq((instExpr :: syntax.AstExprInstantiate).rightarrow2.text, ">")
	end)

	suite:case("parseExprIndexName", function(assert)
		local indexExpr = parser.parseexpr("obj.field")
		assert.eq(indexExpr.tag, "indexname")
		assert.eq(indexExpr.kind, "expr")
		assert.eq((indexExpr :: syntax.AstExprIndexName).expression.tag, "global")
		assert.eq((indexExpr :: syntax.AstExprIndexName).accessor.text, ".")
		assert.eq((indexExpr :: syntax.AstExprIndexName).index.text, "field")
	end)

	suite:case("parseExprIndexExpr", function(assert)
		local indexExpr = parser.parseexpr("arr[1]")
		assert.eq(indexExpr.tag, "index")
		assert.eq(indexExpr.kind, "expr")
		assert.eq((indexExpr :: syntax.AstExprIndexExpr).expression.tag, "global")
		assert.eq((indexExpr :: syntax.AstExprIndexExpr).index.tag, "number")
		assert.eq((indexExpr :: syntax.AstExprIndexExpr).openbrackets.text, "[")
		assert.eq((indexExpr :: syntax.AstExprIndexExpr).closebrackets.text, "]")
	end)

	suite:case("parseExprFunction", function(assert)
		local anonFuncExpr = parser.parseexpr("function(a, b) return a + b end")
		assert.eq(anonFuncExpr.tag, "function")
		assert.eq(anonFuncExpr.kind, "expr")

		local funcExpr = anonFuncExpr :: syntax.AstExprFunction
		assert.eq(#funcExpr.attributes, 0)
		assert.eq(funcExpr.functionkeyword.text, "function")
		assert.eq(funcExpr.opengenerics, nil)
		assert.eq(funcExpr.generics, nil)
		assert.eq(funcExpr.genericpacks, nil)
		assert.eq(funcExpr.closegenerics, nil)
		assert.eq(funcExpr.self, nil)
		assert.eq(funcExpr.openparens.text, "(")
		assert.eq(#funcExpr.parameters, 2)
		assert.eq(funcExpr.parameters[1].node.name.text, "a")
		assert.eq(funcExpr.parameters[2].node.name.text, "b")
		assert.eq(funcExpr.vararg, nil)
		assert.eq(funcExpr.varargcolon, nil)
		assert.eq(funcExpr.varargannotation, nil)
		assert.eq(funcExpr.closeparens.text, ")")
		assert.eq(funcExpr.returnspecifier, nil)
		assert.eq(funcExpr.returnannotation, nil)
		assert.eq(funcExpr.endkeyword.text, "end")

		anonFuncExpr = parser.parseexpr("function<A, B...>(a: A, ...: B...): A return a end")
		assert.eq(anonFuncExpr.tag, "function")
		assert.eq(anonFuncExpr.kind, "expr")

		funcExpr = anonFuncExpr :: syntax.AstExprFunction
		assert.eq(#funcExpr.attributes, 0)
		assert.eq(funcExpr.functionkeyword.text, "function")

		assert.neq(funcExpr.opengenerics, nil)
		assert.neq(funcExpr.generics, nil)

		assert.eq(#funcExpr.generics :: syntax.Punctuated<syntax.AstGenericType>, 1)
		local gen = (funcExpr.generics :: syntax.Punctuated<syntax.AstGenericType>)[1].node
		assert.eq(gen.name.text, "A")
		assert.eq(gen.equals, nil)
		assert.eq(gen.default, nil)

		assert.neq(funcExpr.genericpacks, nil)
		assert.eq(#funcExpr.genericpacks :: syntax.Punctuated<syntax.AstGenericTypePack>, 1)

		local genPack = (funcExpr.genericpacks :: syntax.Punctuated<syntax.AstGenericTypePack>)[1].node
		assert.eq(genPack.name.text, "B")
		assert.eq(genPack.ellipsis.text, "...")
		assert.eq(genPack.equals, nil)
		assert.eq(genPack.default, nil)

		assert.neq(funcExpr.closegenerics, nil)
		assert.eq((funcExpr.closegenerics :: syntax.Token<">">).text, ">")

		assert.eq(funcExpr.openparens.text, "(")
		assert.eq(#funcExpr.parameters, 1)
		local param = funcExpr.parameters[1].node
		assert.eq(param.name.text, "a")
		assert.neq(param.colon, nil)
		assert.eq((param.colon :: syntax.Token<":">).text, ":")
		assert.neq(param.annotation, nil)
		assert.eq((param.annotation :: syntax.AstType).tag, "reference")

		assert.neq(funcExpr.vararg, nil)
		assert.eq((funcExpr.vararg :: syntax.Token<"...">).text, "...")
		assert.neq(funcExpr.varargcolon, nil)
		assert.eq((funcExpr.varargcolon :: syntax.Token<":">).text, ":")
		assert.neq(funcExpr.varargannotation, nil)
		assert.eq((funcExpr.varargannotation :: syntax.AstTypePack).tag, "generic")

		assert.eq(funcExpr.closeparens.text, ")")
		assert.neq(funcExpr.returnspecifier, nil)
		assert.eq((funcExpr.returnspecifier :: syntax.Token<":">).text, ":")
		assert.neq(funcExpr.returnannotation, nil)
		assert.eq((funcExpr.returnannotation :: syntax.AstTypePack).tag, "explicit")
	end)

	suite:case("parseExprTable", function(assert)
		local emptyTableExpr = parser.parseexpr("{}")
		assert.eq(emptyTableExpr.tag, "table")
		assert.eq(emptyTableExpr.kind, "expr")
		local tableExpr = emptyTableExpr :: syntax.AstExprTable
		assert.eq(tableExpr.openbrace.text, "{")
		assert.eq(tableExpr.closebrace.text, "}")
		assert.eq(#tableExpr.entries, 0)

		local mixedTable = parser.parseexpr("{1, foo = bar; [2] = baz}")
		assert.eq(mixedTable.tag, "table")
		assert.eq(mixedTable.kind, "expr")
		local mixedTableExpr = mixedTable :: syntax.AstExprTable
		assert.eq(#mixedTableExpr.entries, 3)

		local entry1 = mixedTableExpr.entries[1]
		assert.eq(entry1.kind, "list")
		assert.eq(entry1.value.tag, "number")
		assert.neq(entry1.separator, nil)
		assert.eq((entry1.separator :: syntax.Token<"," | ";">).text, ",")

		local entry2: any = mixedTableExpr.entries[2]
		assert.eq(entry2.kind, "record")
		assert.eq(entry2.key.text, "foo")
		assert.eq(entry2.equals.text, "=")
		assert.eq(entry2.value.tag, "global")
		assert.neq(entry2.separator, nil)
		assert.eq((entry2.separator :: syntax.Token<"," | ";">).text, ";")

		local entry3: any = mixedTableExpr.entries[3]
		assert.eq(entry3.kind, "general")
		assert.eq(entry3.indexeropen.text, "[")
		assert.eq(entry3.key.tag, "number")
		assert.eq(entry3.indexerclose.text, "]")
		assert.eq(entry3.equals.text, "=")
		assert.eq(entry3.value.tag, "global")
		assert.eq(entry3.separator, nil)
	end)

	suite:case("parseExprUnary", function(assert)
		local notExpr = parser.parseexpr("not x")
		assert.eq(notExpr.tag, "unary")
		assert.eq(notExpr.kind, "expr")
		local expr = notExpr :: syntax.AstExprUnary
		assert.eq(expr.operator.text, "not")
		assert.eq(expr.operand.tag, "global")

		local negExpr = parser.parseexpr("-42")
		assert.eq(negExpr.tag, "unary")
		assert.eq(negExpr.kind, "expr")
		expr = negExpr :: syntax.AstExprUnary
		assert.eq(expr.operator.text, "-")
		assert.eq(expr.operand.tag, "number")

		local lenExpr = parser.parseexpr("#str")
		assert.eq(lenExpr.tag, "unary")
		assert.eq(lenExpr.kind, "expr")
		expr = lenExpr :: syntax.AstExprUnary
		assert.eq(expr.operator.text, "#")
		assert.eq(expr.operand.tag, "global")
	end)

	suite:case("parseExprBinary", function(assert)
		local addExpr = parser.parseexpr("1 + 2")
		assert.eq(addExpr.tag, "binary")
		assert.eq(addExpr.kind, "expr")
		local expr = addExpr :: syntax.AstExprBinary
		assert.eq(expr.lhsoperand.tag, "number")
		assert.eq(expr.operator.text, "+")
		assert.eq(expr.rhsoperand.tag, "number")
	end)

	suite:case("parseExprInterpString", function(assert)
		local interpExpr = parser.parseexpr("`Hello, {name}! Today is {dayOfWeek}.`")
		assert.eq(interpExpr.tag, "interpolatedstring")
		assert.eq(interpExpr.kind, "expr")
		local expr = interpExpr :: syntax.AstExprInterpString
		assert.eq(#expr.strings, 3)

		assert.eq(expr.strings[1].text, "Hello, ")
		assert.eq(expr.strings[2].text, "! Today is ")
		assert.eq(expr.strings[3].text, ".")

		assert.eq(#expr.expressions, 2)
		assert.eq(expr.expressions[1].tag, "global")
		assert.eq(expr.expressions[2].tag, "global")
	end)

	suite:case("parseExprTypeAssertion", function(assert)
		local castExpr = parser.parseexpr("x :: string")
		assert.eq(castExpr.tag, "cast")
		assert.eq(castExpr.kind, "expr")
		local expr = castExpr :: syntax.AstExprTypeAssertion
		assert.eq(expr.operand.tag, "global")
		assert.eq(expr.operator.text, "::")
		assert.eq(expr.annotation.tag, "reference")
	end)

	-- table items serialized with location field
	suite:case("exprTableItemSerializedWithLocationField", function(assert)
		local tableExpr = parser.parseexpr([[
{
1,
foo = bar,
[2] = baz 
}
		]])
		assert.eq(tableExpr.tag, "table")
		assert.eq(tableExpr.kind, "expr")
		tableExpr = tableExpr :: syntax.AstExprTable
		assert.eq(#tableExpr.entries, 3)
		assert.eq(tableExpr.entries[1].location.beginLine, 2)
		assert.eq(tableExpr.entries[1].location.beginColumn, 1)
		assert.eq(tableExpr.entries[1].location.endLine, 2)
		assert.eq(tableExpr.entries[1].location.endColumn, 2)
		assert.eq(tableExpr.entries[2].location.beginLine, 3)
		assert.eq(tableExpr.entries[2].location.beginColumn, 1)
		assert.eq(tableExpr.entries[2].location.endLine, 3)
		assert.eq(tableExpr.entries[2].location.endColumn, 10)
		assert.eq(tableExpr.entries[3].location.beginLine, 4)
		assert.eq(tableExpr.entries[3].location.beginColumn, 1)
		assert.eq(tableExpr.entries[3].location.endLine, 4)
		assert.eq(tableExpr.entries[3].location.endColumn, 10)
	end)
end)

local function checkIsBlock(node: any, assert: testTypes.Asserts)
	assert.eq(node.kind, "stat")
	assert.eq(node.tag, "block")
end

test.suite("parse", function(suite)
	suite:case("parseEmptyProgram", function(assert)
		local block = parser.parseblock("")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 0)
	end)

	suite:case("parseDoStatement", function(assert)
		local block = parser.parseblock("do print('Hello, World!') end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local doStat = block.statements[1] :: syntax.AstStatDo
		assert.eq(doStat.tag, "do")
		assert.eq(doStat.doKeyword.text, "do")
		checkIsBlock(doStat.body, assert)
		assert.eq(#doStat.body.statements, 1)
		assert.eq(doStat.endKeyword.text, "end")
	end)

	suite:case("parseIfStatement", function(assert)
		local block = parser.parseblock(
			"if x > 0 then print('positive') elseif x < 0 then print('negative') else print('zero') end"
		)
		assert.eq(#block.statements, 1)

		local ifStat = block.statements[1] :: syntax.AstStatIf
		assert.eq(ifStat.tag, "conditional")
		assert.eq(ifStat.ifKeyword.text, "if")
		assert.eq(ifStat.condition.tag, "binary")
		assert.eq(ifStat.thenKeyword.text, "then")
		checkIsBlock(ifStat.thenBlock, assert)

		local thenBlock = ifStat.thenBlock
		assert.eq(#thenBlock.statements, 1)

		assert.eq(#ifStat.elseifs, 1)
		local elseIf = ifStat.elseifs[1]
		assert.eq(elseIf.elseIfKeyword.text, "elseif")
		assert.eq(elseIf.condition.tag, "binary")
		assert.eq(elseIf.thenKeyword.text, "then")
		checkIsBlock(elseIf.thenBlock, assert)

		assert.neq(ifStat.elseKeyword, nil)
		assert.eq((ifStat.elseKeyword :: syntax.Token<"else">).text, "else")
		assert.neq(ifStat.elseBlock, nil)
		checkIsBlock(ifStat.elseBlock, assert)
		assert.eq(ifStat.endKeyword.text, "end")

		block = parser.parseblock("if condition then doSomething() end")
		assert.eq(#block.statements, 1)
		local simpleIfStat = block.statements[1] :: syntax.AstStatIf
		assert.eq(simpleIfStat.tag, "conditional")
		assert.eq(simpleIfStat.ifKeyword.text, "if")
		assert.eq(simpleIfStat.condition.tag, "global")
		assert.eq(simpleIfStat.thenKeyword.text, "then")
		checkIsBlock(simpleIfStat.thenBlock, assert)
		assert.eq(#simpleIfStat.thenBlock.statements, 1)
		assert.eq(#simpleIfStat.elseifs, 0)
		assert.eq(simpleIfStat.elseKeyword, nil)
		assert.eq(simpleIfStat.elseBlock, nil)
		assert.eq(simpleIfStat.endKeyword.text, "end")
	end)

	suite:case("parseStatWhile", function(assert)
		local block = parser.parseblock("while i <= 10 do print(i); i = i + 1 end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local whileStat = block.statements[1] :: syntax.AstStatWhile
		assert.eq(whileStat.tag, "while")
		assert.eq(whileStat.whileKeyword.text, "while")
		assert.eq(whileStat.condition.tag, "binary")
		assert.eq(whileStat.doKeyword.text, "do")
		checkIsBlock(whileStat.body, assert)
		assert.eq(#whileStat.body.statements, 2)
		assert.eq(whileStat.endKeyword.text, "end")

		block = parser.parseblock("while true do break end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		whileStat = block.statements[1] :: syntax.AstStatWhile
		assert.eq(whileStat.tag, "while")
		assert.eq(whileStat.whileKeyword.text, "while")
		assert.eq(whileStat.condition.tag, "boolean")
		assert.eq(whileStat.doKeyword.text, "do")
		checkIsBlock(whileStat.body, assert)
		assert.eq(#whileStat.body.statements, 1)

		local breakStat = whileStat.body.statements[1] :: syntax.AstStat
		assert.eq(breakStat.kind, "stat")
		breakStat = breakStat :: syntax.AstStatBreak
		assert.eq(breakStat.tag, "break")
		assert.eq(breakStat.token.text, "break")

		assert.eq(whileStat.endKeyword.text, "end")

		block = parser.parseblock("while true do continue end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		whileStat = block.statements[1] :: syntax.AstStatWhile
		assert.eq(whileStat.tag, "while")
		assert.eq(whileStat.whileKeyword.text, "while")
		assert.eq(whileStat.condition.tag, "boolean")
		assert.eq(whileStat.doKeyword.text, "do")
		checkIsBlock(whileStat.body, assert)
		assert.eq(#whileStat.body.statements, 1)

		local continueStat = whileStat.body.statements[1] :: syntax.AstStat
		assert.eq(continueStat.kind, "stat")
		continueStat = continueStat :: syntax.AstStatContinue
		assert.eq(continueStat.tag, "continue")
		assert.eq(continueStat.token.text, "continue")

		assert.eq(whileStat.endKeyword.text, "end")
	end)

	suite:case("parseStatRepeat", function(assert)
		local block = parser.parseblock("repeat i = i + 1; print(i) until i > 5")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local repeatStat = block.statements[1] :: syntax.AstStatRepeat
		assert.eq(repeatStat.tag, "repeat")
		assert.eq(repeatStat.repeatKeyword.text, "repeat")
		checkIsBlock(repeatStat.body, assert)
		assert.eq(#repeatStat.body.statements, 2)
		assert.eq(repeatStat.untilKeyword.text, "until")
		assert.eq(repeatStat.condition.tag, "binary")
	end)

	suite:case("parseStatLocal", function(assert)
		local block = parser.parseblock("local b, c = 1, 2")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)
		assert.eq(block.statements[1].kind, "stat")

		local l = block.statements[1] :: syntax.AstStatLocal
		assert.eq(l.tag, "local")
		assert.eq(l.localKeyword.text, "local")
		assert.eq(#l.variables, 2)
		assert.eq(l.variables[1].node.name.text, "b")
		assert.neq(l.variables[1].separator, nil)
		assert.eq((l.variables[1].separator :: syntax.Token<",">).text, ",")
		assert.eq(l.variables[2].node.name.text, "c")
		assert.eq(l.variables[2].separator, nil)
		assert.neq(l.equals, nil)
		assert.eq((l.equals :: syntax.Token<"=">).text, "=")
		assert.eq(#l.values, 2)
		assert.eq(l.values[1].node.tag, "number")
		assert.neq(l.values[1].separator, nil)
		assert.eq((l.values[1].separator :: syntax.Token<",">).text, ",")
		assert.eq(l.values[2].node.tag, "number")
		assert.eq(l.values[2].separator, nil)

		block = parser.parseblock("local x")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)
		assert.eq(block.statements[1].kind, "stat")

		l = block.statements[1] :: syntax.AstStatLocal
		assert.eq(l.tag, "local")
		assert.eq(l.localKeyword.text, "local")
		assert.eq(#l.variables, 1)
		assert.eq(l.variables[1].node.name.text, "x")
		assert.eq(l.variables[1].separator, nil)
		assert.eq(l.equals, nil)
		assert.eq(#l.values, 0)
	end)

	suite:case("parseStatFor", function(assert)
		local block = parser.parseblock("for i = 1, 10, 2 do print(i) end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local forStat = block.statements[1] :: syntax.AstStatFor
		assert.eq(forStat.tag, "for")
		assert.eq(forStat.forKeyword.text, "for")
		assert.eq(forStat.variable.name.text, "i")
		assert.eq(forStat.equals.text, "=")
		assert.eq(forStat.from.tag, "number")
		assert.eq(forStat.toComma.text, ",")
		assert.eq(forStat.to.tag, "number")
		assert.neq(forStat.stepComma, nil)
		assert.eq((forStat.stepComma :: syntax.Token<",">).text, ",")
		assert.neq(forStat.step, nil)
		assert.eq(((forStat.step :: any) :: syntax.AstExpr).tag, "number")
		assert.eq(forStat.doKeyword.text, "do")
		checkIsBlock(forStat.body, assert)
		assert.eq(#forStat.body.statements, 1)
		assert.eq(forStat.endKeyword.text, "end")

		block = parser.parseblock("for j = 0, 5 do print(j) end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		forStat = block.statements[1] :: syntax.AstStatFor
		assert.eq(forStat.tag, "for")
		assert.eq(forStat.forKeyword.text, "for")
		assert.eq(forStat.variable.name.text, "j")
		assert.eq(forStat.equals.text, "=")
		assert.eq(forStat.from.tag, "number")
		assert.eq(forStat.toComma.text, ",")
		assert.eq(forStat.to.tag, "number")
		assert.eq(forStat.stepComma, nil)
		assert.eq(forStat.step, nil)
		assert.eq(forStat.doKeyword.text, "do")
		checkIsBlock(forStat.body, assert)
		assert.eq(#forStat.body.statements, 1)
		assert.eq(forStat.endKeyword.text, "end")
	end)

	suite:case("parseForInLoop", function(assert)
		local block = parser.parseblock("for key, value in arr do print(key, value) end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local forInStat = block.statements[1] :: syntax.AstStatForIn
		assert.eq(forInStat.tag, "forin")
		assert.eq(forInStat.forKeyword.text, "for")
		assert.eq(#forInStat.variables, 2)
		assert.eq(forInStat.variables[1].node.name.text, "key")
		assert.eq(forInStat.variables[2].node.name.text, "value")
		assert.eq(forInStat.inKeyword.text, "in")
		assert.eq(#forInStat.values, 1)
		assert.eq(forInStat.values[1].node.tag, "global")
		assert.eq(forInStat.doKeyword.text, "do")
		checkIsBlock(forInStat.body, assert)
		assert.eq(#forInStat.body.statements, 1)
		assert.eq(forInStat.endKeyword.text, "end")
	end)

	suite:case("parseStatAssign", function(assert)
		local block = parser.parseblock("x = 1")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local assign = block.statements[1] :: syntax.AstStatAssign
		assert.eq(assign.tag, "assign")
		assert.eq(#assign.variables, 1)
		assert.eq(assign.variables[1].node.tag, "global")
		assert.eq(assign.equals.text, "=")
		assert.eq(#assign.values, 1)
		assert.eq(assign.values[1].node.tag, "number")
	end)

	suite:case("parseStatCompoundAssign", function(assert)
		local block = parser.parseblock("x += 5")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local compound = block.statements[1] :: syntax.AstStatCompoundAssign
		assert.eq(compound.tag, "compoundassign")
		assert.eq(compound.variable.tag, "global")
		assert.eq(compound.operand.text, "+=")
		assert.eq(compound.value.tag, "number")
	end)

	suite:case("parseStatFunction", function(assert)
		local block = parser.parseblock("@checked @native @deprecated function add(a, b) return a + b end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local funcStat = block.statements[1] :: syntax.AstStatFunction
		assert.eq(funcStat.tag, "function")
		assert.eq(#funcStat.func.attributes, 3)
		assert.eq((funcStat.func.attributes[1] :: syntax.AstAttribute).token.text, "@checked")
		assert.eq((funcStat.func.attributes[2] :: syntax.AstAttribute).token.text, "@native")
		assert.eq((funcStat.func.attributes[3] :: syntax.AstAttribute).token.text, "@deprecated")
		assert.eq(funcStat.func.functionkeyword.text, "function")
		assert.eq(funcStat.name.tag, "global")
		assert.eq((funcStat.name :: syntax.AstExprGlobal).name.text, "add")
		-- body parsing tested in parseExprFunction
	end)

	suite:case("parseStatLocalFunction", function(assert)
		local block = parser.parseblock("local function multiply(x, y) return x * y end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local localFuncStat = block.statements[1] :: syntax.AstStatLocalFunction
		assert.eq(localFuncStat.tag, "localfunction")
		assert.eq(#localFuncStat.func.attributes, 0)
		assert.eq(localFuncStat.localKeyword.text, "local")
		assert.eq(localFuncStat.func.functionkeyword.text, "function")
		assert.eq(localFuncStat.name.name.text, "multiply")
	end)

	suite:case("parseStatTypeAlias", function(assert)
		local block = parser.parseblock("type Vector3 = {x: number, y: number, z: number}")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.tag, "typealias")
		assert.eq(typeAlias.export, nil)
		assert.eq(typeAlias.typeToken.text, "type")
		assert.eq(typeAlias.name.text, "Vector3")
		assert.eq(typeAlias.openGenerics, nil)
		assert.eq(typeAlias.generics, nil)
		assert.eq(typeAlias.closeGenerics, nil)
		assert.eq(typeAlias.equals.text, "=")
		assert.eq(typeAlias.type.kind, "type")
		assert.eq(typeAlias.type.tag, "table")

		block = parser.parseblock("export type Point<T, U...> = {x: T, y: T, f: (U...) -> ()}")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.neq(typeAlias.export, nil)
		assert.eq((typeAlias.export :: syntax.Token<"export">).text, "export")
		assert.neq(typeAlias.openGenerics, nil)
		assert.eq((typeAlias.openGenerics :: syntax.Token<"<">).text, "<")
		assert.neq(typeAlias.generics, nil)
		assert.eq(#typeAlias.generics :: syntax.Punctuated<syntax.AstGenericType>, 1)
		assert.neq(typeAlias.genericPacks, nil)
		assert.eq(#typeAlias.genericPacks :: syntax.Punctuated<syntax.AstGenericTypePack>, 1)
		assert.neq(typeAlias.closeGenerics, nil)
		assert.eq((typeAlias.closeGenerics :: syntax.Token<">">).text, ">")
	end)

	suite:case("parseStatTypeFunction", function(assert)
		local block = parser.parseblock("type function foo() return types.number end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local typeFunc = block.statements[1] :: syntax.AstStatTypeFunction
		assert.eq(typeFunc.tag, "typefunction")
		assert.eq(typeFunc.export, nil)
		assert.eq(typeFunc.type.text, "type")
		assert.eq(typeFunc.body.functionkeyword.text, "function")
		assert.eq(typeFunc.name.text, "foo")

		block = parser.parseblock("export type function foo() return types.number end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		typeFunc = block.statements[1] :: syntax.AstStatTypeFunction
		assert.neq(typeFunc.export, nil)
		assert.eq((typeFunc.export :: syntax.Token<"export">).text, "export")
	end)
end)

test.suite("parse types", function(suite)
	-- AstGenericType and AstGenericTypePack are tested in parseExprFunction
	suite:case("testTypeReference", function(assert)
		local block = parser.parseblock("type MyString = string")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "reference")

		local typeRef = typeAlias.type :: syntax.AstTypeReference
		assert.eq(typeRef.prefix, nil)
		assert.eq(typeRef.prefixpoint, nil)
		assert.eq(typeRef.name.text, "string")
		assert.eq(typeRef.openparameters, nil)
		assert.eq(typeRef.parameters, nil)
		assert.eq(typeRef.closeparameters, nil)

		block = parser.parseblock("type MyTable = MyModule.Table<number, string>")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "reference")

		typeRef = typeAlias.type :: syntax.AstTypeReference
		assert.neq(typeRef.prefix, nil)
		assert.eq((typeRef.prefix :: syntax.Token<string>).text, "MyModule")
		assert.neq(typeRef.prefixpoint, nil)
		assert.eq((typeRef.prefixpoint :: syntax.Token<".">).text, ".")
		assert.eq(typeRef.name.text, "Table")
		assert.neq(typeRef.openparameters, nil)
		assert.eq((typeRef.openparameters :: syntax.Token<"<">).text, "<")
		assert.neq(typeRef.parameters, nil)
		assert.eq(#typeRef.parameters :: syntax.Punctuated<syntax.AstType>, 2)
		assert.eq((typeRef.parameters :: syntax.Punctuated<syntax.AstType>)[1].node.tag, "reference")
		assert.eq((typeRef.parameters :: syntax.Punctuated<syntax.AstType>)[2].node.tag, "reference")
		assert.neq(typeRef.closeparameters, nil)
		assert.eq((typeRef.closeparameters :: syntax.Token<">">).text, ">")
	end)

	suite:case("testTypeSingletonBoolean", function(assert)
		local block = parser.parseblock("type TrueType = true")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "boolean")

		local singletonBool = typeAlias.type :: syntax.AstTypeSingletonBool
		assert.eq(singletonBool.token.text, "true")
		assert.that(singletonBool.value)

		block = parser.parseblock("type FalseType = false")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "boolean")

		singletonBool = typeAlias.type :: syntax.AstTypeSingletonBool
		assert.eq(singletonBool.token.text, "false")
		assert.eq(singletonBool.value, false)
	end)

	suite:case("testTypeSingletonString", function(assert)
		local block = parser.parseblock("type HelloType = 'hello'")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "string")

		local singletonStr = typeAlias.type :: syntax.AstTypeSingletonString
		assert.eq(singletonStr.token.text, "hello")
		assert.eq(singletonStr.quotestyle, "single")

		block = parser.parseblock('type WorldType = "world"')
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "string")

		singletonStr = typeAlias.type :: syntax.AstTypeSingletonString
		assert.eq(singletonStr.token.text, "world")
		assert.eq(singletonStr.quotestyle, "double")
	end)

	suite:case("testTypeTypeof", function(assert)
		local block = parser.parseblock("type T = typeof(someVariable)")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "typeof")

		local typeofType = typeAlias.type :: syntax.AstTypeTypeof
		assert.eq(typeofType.typeof.text, "typeof")
		assert.eq(typeofType.openparens.text, "(")
		assert.eq(typeofType.expression.tag, "global")
		assert.eq(typeofType.closeparens.text, ")")
	end)

	suite:case("testTypeGroup", function(assert)
		local block = parser.parseblock("type T = (string)")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "group")

		local groupType = typeAlias.type :: syntax.AstTypeGroup
		assert.eq(groupType.openparens.text, "(")
		assert.eq(groupType.type.tag, "reference")
		assert.eq(groupType.closeparens.text, ")")
	end)

	suite:case("testTypeUnion", function(assert)
		local block = parser.parseblock("type T = string | number | boolean")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "union")

		local unionType = typeAlias.type :: syntax.AstTypeUnion
		assert.eq(unionType.leading, nil)
		assert.eq(#unionType.types, 3)
		assert.eq(unionType.types[1].node.tag, "reference")
		assert.eq(unionType.types[2].node.tag, "reference")
		assert.eq(unionType.types[3].node.tag, "reference")

		block = parser.parseblock("type T = | number?")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "union")

		unionType = typeAlias.type :: syntax.AstTypeUnion
		assert.neq(unionType.leading, nil)
		assert.eq((unionType.leading :: syntax.Token<"|">).text, "|")
		assert.eq(#unionType.types, 2)
		assert.eq(unionType.types[1].node.tag, "reference")
		assert.eq(unionType.types[2].node.tag, "optional")
		assert.eq((unionType.types[2].node :: syntax.AstTypeOptional).token.text, "?")
	end)

	suite:case("testTypeUnionWithOptionalPart", function(assert)
		local block = parser.parseblock("type T = number? | string")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "union")

		local unionType = typeAlias.type :: syntax.AstTypeUnion
		assert.eq(unionType.leading, nil)
		assert.eq(#unionType.types, 3)

		local pair1 = unionType.types[1]
		assert.eq(pair1.node.tag, "reference")
		assert.eq(pair1.separator, nil)

		local pair2 = unionType.types[2]
		assert.eq(pair2.node.tag, "optional")
		assert.neq(pair2.separator, nil)
		assert.eq((pair2.separator :: syntax.Token<"|">).text, "|")

		local pair3 = unionType.types[3]
		assert.eq(pair3.node.tag, "reference")
		assert.eq(pair3.separator, nil)
	end)

	suite:case("testTypeIntersection", function(assert)
		local block = parser.parseblock("type T = A & B & C")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "intersection")

		local intersectionType = typeAlias.type :: syntax.AstTypeIntersection
		assert.eq(intersectionType.leading, nil)
		assert.eq(#intersectionType.types, 3)
		assert.eq(intersectionType.types[1].node.tag, "reference")
		assert.eq(intersectionType.types[2].node.tag, "reference")
		assert.eq(intersectionType.types[3].node.tag, "reference")

		block = parser.parseblock("type T = & B")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "intersection")

		intersectionType = typeAlias.type :: syntax.AstTypeIntersection
		assert.neq(intersectionType.leading, nil)
		assert.eq((intersectionType.leading :: syntax.Token<"&">).text, "&")
		assert.eq(#intersectionType.types, 1)
		assert.eq(intersectionType.types[1].node.tag, "reference")
	end)

	suite:case("testTypeArray", function(assert)
		local block = parser.parseblock("type T = { number }")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "array")

		local arrayType = typeAlias.type :: syntax.AstTypeArray
		assert.eq(arrayType.openbrace.text, "{")
		assert.eq(arrayType.access, nil)
		assert.eq(arrayType.type.tag, "reference")
		assert.eq(arrayType.closebrace.text, "}")

		block = parser.parseblock("type T = { read string }")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "array")

		arrayType = typeAlias.type :: syntax.AstTypeArray
		assert.neq(arrayType.access, nil)
		assert.eq((arrayType.access :: syntax.Token<"read" | "write">).text, "read")

		block = parser.parseblock("type T = { write number }")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "array")

		arrayType = typeAlias.type :: syntax.AstTypeArray
		assert.neq(arrayType.access, nil)
		assert.eq((arrayType.access :: syntax.Token<"read" | "write">).text, "write")
	end)

	suite:case("parseTypeTable", function(assert)
		local block = parser.parseblock("type T = {}")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")

		local tableType = typeAlias.type :: syntax.AstTypeTable
		assert.eq(tableType.openbrace.text, "{")
		assert.eq(#tableType.entries, 0)
		assert.eq(tableType.closebrace.text, "}")

		block = parser.parseblock("type T = {[number] : string}")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")

		tableType = typeAlias.type :: syntax.AstTypeTable
		assert.eq(#tableType.entries, 1)
		local tableTypeItem: any = tableType.entries[1]
		assert.eq(tableTypeItem.kind, "indexer")
		assert.eq(tableTypeItem.access, nil)
		assert.eq(tableTypeItem.indexeropen.text, "[")
		assert.eq(tableTypeItem.key.tag, "reference")
		assert.eq(tableTypeItem.indexerclose.text, "]")
		assert.eq(tableTypeItem.colon.text, ":")
		assert.eq(tableTypeItem.value.tag, "reference")
		assert.eq(tableTypeItem.separator, nil)

		block = parser.parseblock("type T = {['hello'] : 'world', read ['foo'] : number; write ['bar'] : boolean}")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")
		tableType = typeAlias.type :: syntax.AstTypeTable
		assert.eq(#tableType.entries, 3)
		tableTypeItem = tableType.entries[1]
		assert.eq(tableTypeItem.kind, "stringproperty")
		assert.eq(tableTypeItem.access, nil)
		assert.eq(tableTypeItem.indexeropen.text, "[")
		assert.eq((tableTypeItem.key :: syntax.AstTypeSingletonString).kind, "type")
		assert.eq((tableTypeItem.key :: syntax.AstTypeSingletonString).tag, "string")
		assert.eq((tableTypeItem.key :: syntax.AstTypeSingletonString).token.text, "hello")
		assert.eq(tableTypeItem.indexerclose.text, "]")
		assert.eq(tableTypeItem.colon.text, ":")
		assert.eq(tableTypeItem.value.tag, "string")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.Token<"," | ";">).text, ",")

		tableTypeItem = tableType.entries[2]
		assert.eq(tableTypeItem.kind, "stringproperty")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.Token<"read" | "write">).text, "read")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.Token<"," | ";">).text, ";")

		tableTypeItem = tableType.entries[3]
		assert.eq(tableTypeItem.kind, "stringproperty")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.Token<"read" | "write">).text, "write")
		assert.eq(tableTypeItem.separator, nil)

		block = parser.parseblock("type T = { hello: 'world'; read foo: number, write bar: boolean }")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")
		tableType = typeAlias.type :: syntax.AstTypeTable
		assert.eq(#tableType.entries, 3)
		tableTypeItem = tableType.entries[1]
		assert.eq(tableTypeItem.kind, "property")
		assert.eq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.key :: syntax.Token).text, "hello")
		assert.eq(tableTypeItem.colon.text, ":")
		assert.eq(tableTypeItem.value.tag, "string")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.Token<"," | ";">).text, ";")

		tableTypeItem = tableType.entries[2]
		assert.eq(tableTypeItem.kind, "property")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.Token<"read" | "write">).text, "read")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.Token<"," | ";">).text, ",")

		tableTypeItem = tableType.entries[3]
		assert.eq(tableTypeItem.kind, "property")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.Token<"read" | "write">).text, "write")
		assert.eq(tableTypeItem.separator, nil)
	end)

	suite:case("parseTypeFunction", function(assert)
		local block = parser.parseblock("type T = (n : number, string) -> boolean")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "function")

		local funcType = typeAlias.type :: syntax.AstTypeFunction
		assert.eq(funcType.opengenerics, nil)
		assert.eq(funcType.generics, nil)
		assert.eq(funcType.genericpacks, nil)
		assert.eq(funcType.closegenerics, nil)
		assert.eq(funcType.openparens.text, "(")
		assert.eq(#funcType.parameters, 2)

		local param = funcType.parameters[1].node
		assert.neq(param.name, nil)
		assert.eq((param.name :: syntax.Token<string>).text, "n")
		assert.neq(param.colon, nil)
		assert.eq((param.colon :: syntax.Token<":">).text, ":")
		assert.eq(param.type.tag, "reference")

		param = funcType.parameters[2].node
		assert.eq(param.name, nil)
		assert.eq(param.colon, nil)
		assert.eq(param.type.tag, "reference")

		assert.eq(funcType.vararg, nil)
		assert.eq(funcType.closeparens.text, ")")
		assert.eq(funcType.returnarrow.text, "->")
		assert.eq(funcType.returntypes.kind, "typepack")

		block = parser.parseblock("type T = <T, U...> (item: T, ...U) -> ()")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "function")

		funcType = typeAlias.type :: syntax.AstTypeFunction
		assert.neq(funcType.opengenerics, nil)
		assert.eq((funcType.opengenerics :: syntax.Token<"<">).text, "<")
		assert.neq(funcType.generics, nil)
		assert.eq(#funcType.generics :: syntax.Punctuated<syntax.AstGenericType>, 1)
		assert.neq(funcType.genericpacks, nil)
		assert.eq(#funcType.genericpacks :: syntax.Punctuated<syntax.AstGenericTypePack>, 1)
		assert.eq((funcType.genericpacks :: syntax.Punctuated<syntax.AstGenericTypePack>)[1].node.tag, "generic")

		local genericTypePack = (funcType.genericpacks :: syntax.Punctuated<syntax.AstGenericTypePack>)[1].node
		assert.eq(genericTypePack.name.text, "U")
		assert.eq(genericTypePack.ellipsis.text, "...")

		assert.neq(funcType.closegenerics, nil)
		assert.eq((funcType.closegenerics :: syntax.Token<">">).text, ">")
		assert.neq(funcType.vararg, nil)
		assert.eq((funcType.vararg :: syntax.AstTypePack).kind, "typepack")

		block = parser.parseblock("type T = () -> ...number")
		typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.type.tag, "function")

		funcType = typeAlias.type :: syntax.AstTypeFunction
		assert.eq(funcType.returntypes.kind, "typepack")
		assert.eq(funcType.returntypes.tag, "variadic")
		local variadicType: syntax.AstTypePackVariadic = funcType.returntypes :: any
		assert.neq(variadicType.ellipsis, nil)
		assert.eq((variadicType.ellipsis :: syntax.Token<"...">).text, "...")
		assert.eq(variadicType.type.tag, "reference")
	end)
end)

test.suite("AST_nodes_frozen", function(suite)
	local frozenTableMessage = "attempt to modify a readonly table"

	-- Expression nodes
	suite:case("astExprGroupFrozen", function(assert)
		local expr = parser.parseexpr("(x)")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "group")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
	end)

	suite:case("astExprConstantNilFrozen", function(assert)
		local expr = parser.parseexpr("nil")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "nil")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("astExprConstantBoolFrozen", function(assert)
		local expr = parser.parseexpr("true")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "boolean")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("astExprConstantNumberFrozen", function(assert)
		local expr = parser.parseexpr("42")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "number")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("astExprConstantStringFrozen", function(assert)
		local expr = parser.parseexpr("'hello'")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "string")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("astExprLocalFrozen", function(assert)
		local block = parser.parseblock("local x = 1\nreturn x")
		local returnStat = block.statements[2] :: syntax.AstStatReturn
		local expr = returnStat.expressions[1].node
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "local")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).upvalue = true
		end)
	end)

	suite:case("astExprGlobalFrozen", function(assert)
		local expr = parser.parseexpr("_G")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "global")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).name = nil
		end)
	end)

	suite:case("astExprVarargsFrozen", function(assert)
		local expr = parser.parseexpr("...")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "vararg")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
	end)

	suite:case("astExprCallFrozen", function(assert)
		local expr = parser.parseexpr("foo(1, 2)")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "call")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).func = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).arguments, nil :: any)
		end)
	end)

	suite:case("astExprInstantiateFrozen", function(assert)
		local callExpr = parser.parseexpr("foo<<number, string>>()")
		assert.eq(callExpr.tag, "call")
		local expr = (callExpr :: syntax.AstExprCall).func
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "instantiate")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).expr = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).typearguments, nil :: any)
		end)
	end)

	suite:case("astExprIndexNameFrozen", function(assert)
		local expr = parser.parseexpr("obj.field")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "indexname")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).expression = nil
		end)
	end)

	suite:case("astExprIndexExprFrozen", function(assert)
		local expr = parser.parseexpr("obj[key]")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "index")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).expression = nil
		end)
	end)

	suite:case("astExprFunctionFrozen", function(assert)
		local expr = parser.parseexpr("@checked function<A, B...>(x, y) return x + y end")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "function")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).body = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).parameters, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).attributes, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			((expr :: syntax.AstExprFunction).attributes[1] :: any).token.text = "@modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).generics, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).genericpacks, nil :: any)
		end)
	end)

	suite:case("astExprTableFrozen", function(assert)
		local expr = parser.parseexpr("{ a = 1, [2] = 3, 4 }")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "table")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).openbrace = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).entries, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).entries[1].kind = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).entries[2].kind = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).entries[3].kind = nil
		end)
	end)

	suite:case("astExprUnaryFrozen", function(assert)
		local expr = parser.parseexpr("-x")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "unary")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).operand = nil
		end)
	end)

	suite:case("astExprBinaryFrozen", function(assert)
		local expr = parser.parseexpr("x + y")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "binary")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).lhsoperand = nil
		end)
	end)

	suite:case("astExprInterpStringFrozen", function(assert)
		local expr = parser.parseexpr("`hello {x}`")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "interpolatedstring")
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).strings, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).expressions, nil :: any)
		end)
	end)

	suite:case("astExprTypeAssertionFrozen", function(assert)
		local expr = parser.parseexpr("x :: number")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "cast")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).operand = nil
		end)
	end)

	suite:case("astExprIfElseFrozen", function(assert)
		local expr = parser.parseexpr("if x then 1 elseif y then 2 else 3")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "conditional")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).condition = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).elseifs, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).elseifs[1].condition = nil
		end)
	end)

	-- Statement nodes
	suite:case("astStatBlockFrozen", function(assert)
		local block = parser.parseblock("local x = 1\nlocal y = 2")
		assert.eq(block.kind, "stat")
		assert.eq(block.tag, "block")
		assert.throwsWith(frozenTableMessage, function()
			table.insert((block :: any).statements, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			(block :: any).tag = nil
		end)
	end)

	suite:case("astStatDoFrozen", function(assert)
		local block = parser.parseblock("do local x = 1 end")
		local doStat = block.statements[1] :: syntax.AstStatDo
		assert.eq(doStat.kind, "stat")
		assert.eq(doStat.tag, "do")
		assert.throwsWith(frozenTableMessage, function()
			(doStat :: any).body = nil
		end)
	end)

	suite:case("astStatIfFrozen", function(assert)
		local block = parser.parseblock("if x then local y = 1 elseif z then local w = 2 else local v = 3 end")
		local ifStat = block.statements[1] :: syntax.AstStatIf
		assert.eq(ifStat.kind, "stat")
		assert.eq(ifStat.tag, "conditional")
		assert.throwsWith(frozenTableMessage, function()
			(ifStat :: any).condition = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((ifStat :: any).elseifs, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			(ifStat :: any).elseifs[1].condition = nil
		end)
	end)

	suite:case("astStatWhileFrozen", function(assert)
		local block = parser.parseblock("while x do local y = 1 end")
		local whileStat = block.statements[1] :: syntax.AstStatWhile
		assert.eq(whileStat.kind, "stat")
		assert.eq(whileStat.tag, "while")
		assert.throwsWith(frozenTableMessage, function()
			(whileStat :: any).condition = nil
		end)
	end)

	suite:case("astStatRepeatFrozen", function(assert)
		local block = parser.parseblock("repeat local x = 1 until x > 10")
		local repeatStat = block.statements[1] :: syntax.AstStatRepeat
		assert.eq(repeatStat.kind, "stat")
		assert.eq(repeatStat.tag, "repeat")
		assert.throwsWith(frozenTableMessage, function()
			(repeatStat :: any).body = nil
		end)
	end)

	suite:case("astStatBreakFrozen", function(assert)
		local block = parser.parseblock("while true do break end")
		local whileStat = block.statements[1] :: syntax.AstStatWhile
		local breakStat = whileStat.body.statements[1] :: syntax.AstStatBreak
		assert.eq(breakStat.kind, "stat")
		assert.eq(breakStat.tag, "break")
		assert.throwsWith(frozenTableMessage, function()
			(breakStat :: any).tag = "modified"
		end)
	end)

	suite:case("astStatContinueFrozen", function(assert)
		local block = parser.parseblock("while true do continue end")
		local whileStat = block.statements[1] :: syntax.AstStatWhile
		local continueStat = whileStat.body.statements[1] :: syntax.AstStatContinue
		assert.eq(continueStat.kind, "stat")
		assert.eq(continueStat.tag, "continue")
		assert.throwsWith(frozenTableMessage, function()
			(continueStat :: any).tag = "modified"
		end)
	end)

	suite:case("astStatReturnFrozen", function(assert)
		local block = parser.parseblock("return 1, 2, 3")
		local returnStat = block.statements[1] :: syntax.AstStatReturn
		assert.eq(returnStat.kind, "stat")
		assert.eq(returnStat.tag, "return")
		assert.throwsWith(frozenTableMessage, function()
			(returnStat :: any).returnKeyword = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((returnStat :: any).expressions, nil)
		end)
	end)

	suite:case("astStatExprFrozen", function(assert)
		local block = parser.parseblock("foo()")
		local exprStat = block.statements[1] :: syntax.AstStatExpr
		assert.eq(exprStat.kind, "stat")
		assert.eq(exprStat.tag, "expression")
		assert.throwsWith(frozenTableMessage, function()
			(exprStat :: any).expression = nil
		end)
	end)

	suite:case("astStatLocalFrozen", function(assert)
		local block = parser.parseblock("local x, y = 1, 2")
		local localStat = block.statements[1] :: syntax.AstStatLocal
		assert.eq(localStat.kind, "stat")
		assert.eq(localStat.tag, "local")
		assert.throwsWith(frozenTableMessage, function()
			(localStat :: any).localKeyword = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((localStat :: any).variables, nil)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((localStat :: any).values, nil)
		end)
	end)

	suite:case("astStatForFrozen", function(assert)
		local block = parser.parseblock("for i = 1, 10, 2 do local x = i end")
		local forStat = block.statements[1] :: syntax.AstStatFor
		assert.eq(forStat.kind, "stat")
		assert.eq(forStat.tag, "for")
		assert.throwsWith(frozenTableMessage, function()
			(forStat :: any).variable = nil
		end)
	end)

	suite:case("astStatForInFrozen", function(assert)
		local block = parser.parseblock("for k, v in pairs(t) do local x = k end")
		local forInStat = block.statements[1] :: syntax.AstStatForIn
		assert.eq(forInStat.kind, "stat")
		assert.eq(forInStat.tag, "forin")
		assert.throwsWith(frozenTableMessage, function()
			(forInStat :: any).inKeyword = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((forInStat :: any).variables, nil)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((forInStat :: any).values, nil)
		end)
	end)

	suite:case("astStatAssignFrozen", function(assert)
		local block = parser.parseblock("x, y = 1, 2")
		local assignStat = block.statements[1] :: syntax.AstStatAssign
		assert.eq(assignStat.kind, "stat")
		assert.eq(assignStat.tag, "assign")
		assert.throwsWith(frozenTableMessage, function()
			(assignStat :: any).equals = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((assignStat :: any).variables, nil)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((assignStat :: any).values, nil)
		end)
	end)

	suite:case("astStatCompoundAssignFrozen", function(assert)
		local block = parser.parseblock("x += 5")
		local compoundStat = block.statements[1] :: syntax.AstStatCompoundAssign
		assert.eq(compoundStat.kind, "stat")
		assert.eq(compoundStat.tag, "compoundassign")
		assert.throwsWith(frozenTableMessage, function()
			(compoundStat :: any).variable = nil
		end)
	end)

	suite:case("astStatFunctionFrozen", function(assert)
		local block = parser.parseblock("function foo() end")
		local funcStat = block.statements[1] :: syntax.AstStatFunction
		assert.eq(funcStat.kind, "stat")
		assert.eq(funcStat.tag, "function")
		assert.throwsWith(frozenTableMessage, function()
			(funcStat :: any).name = nil
		end)
	end)

	suite:case("astStatLocalFunctionFrozen", function(assert)
		local block = parser.parseblock("local function foo() end")
		local localFuncStat = block.statements[1] :: syntax.AstStatLocalFunction
		assert.eq(localFuncStat.kind, "stat")
		assert.eq(localFuncStat.tag, "localfunction")
		assert.throwsWith(frozenTableMessage, function()
			(localFuncStat :: any).name = nil
		end)
	end)

	suite:case("astStatTypeAliasFrozen", function(assert)
		local block = parser.parseblock("type Foo<T> = T")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		assert.eq(typeAlias.kind, "stat")
		assert.eq(typeAlias.tag, "typealias")
		assert.throwsWith(frozenTableMessage, function()
			(typeAlias :: any).name = nil
		end)
	end)

	suite:case("astStatTypeFunctionFrozen", function(assert)
		local block = parser.parseblock("type function foo() return function() end end")
		local typeFunc = block.statements[1] :: syntax.AstStatTypeFunction
		assert.eq(typeFunc.kind, "stat")
		assert.eq(typeFunc.tag, "typefunction")
		assert.throwsWith(frozenTableMessage, function()
			(typeFunc :: any).name = nil
		end)
	end)

	-- Type nodes
	suite:case("astTypeReferenceFrozen", function(assert)
		local block = parser.parseblock("type Foo = Bar<T>")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local typeRef = typeAlias.type :: syntax.AstTypeReference
		assert.eq(typeRef.kind, "type")
		assert.eq(typeRef.tag, "reference")
		assert.throwsWith(frozenTableMessage, function()
			(typeRef :: any).name = nil
		end)
	end)

	suite:case("astTypeSingletonBoolFrozen", function(assert)
		local block = parser.parseblock("type Foo = true")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local singletonBool = typeAlias.type :: syntax.AstTypeSingletonBool
		assert.eq(singletonBool.kind, "type")
		assert.eq(singletonBool.tag, "boolean")
		assert.throwsWith(frozenTableMessage, function()
			(singletonBool :: any).value = false
		end)
	end)

	suite:case("astTypeSingletonStringFrozen", function(assert)
		local block = parser.parseblock("type Foo = 'hello'")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local singletonStr = typeAlias.type :: syntax.AstTypeSingletonString
		assert.eq(singletonStr.kind, "type")
		assert.eq(singletonStr.tag, "string")
		assert.throwsWith(frozenTableMessage, function()
			(singletonStr :: any).quotestyle = "double"
		end)
	end)

	suite:case("astTypeTypeofFrozen", function(assert)
		local block = parser.parseblock("type Foo = typeof(x)")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local typeofType = typeAlias.type :: syntax.AstTypeTypeof
		assert.eq(typeofType.kind, "type")
		assert.eq(typeofType.tag, "typeof")
		assert.throwsWith(frozenTableMessage, function()
			(typeofType :: any).expression = nil
		end)
	end)

	suite:case("astTypeGroupFrozen", function(assert)
		local block = parser.parseblock("type Foo = (Bar)")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local groupType = typeAlias.type :: syntax.AstTypeGroup
		assert.eq(groupType.kind, "type")
		assert.eq(groupType.tag, "group")
		assert.throwsWith(frozenTableMessage, function()
			(groupType :: any).type = nil
		end)
	end)

	suite:case("astTypeOptionalFrozen", function(assert)
		local block = parser.parseblock("type Foo = string?")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local unionType = typeAlias.type :: syntax.AstTypeUnion
		local optionalType = unionType.types[2].node :: syntax.AstTypeOptional
		assert.eq(optionalType.kind, "type")
		assert.eq(optionalType.tag, "optional")
		assert.throwsWith(frozenTableMessage, function()
			(optionalType :: any).kind = "modified"
		end)
	end)

	suite:case("astTypeUnionFrozen", function(assert)
		local block = parser.parseblock("type Foo = string | number")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local unionType = typeAlias.type :: syntax.AstTypeUnion
		assert.eq(unionType.kind, "type")
		assert.eq(unionType.tag, "union")
		assert.throwsWith(frozenTableMessage, function()
			(unionType :: any).leading = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((unionType :: any).types, nil)
		end)
	end)

	suite:case("astTypeIntersectionFrozen", function(assert)
		local block = parser.parseblock("type Foo = A & B")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local intersectionType = typeAlias.type :: syntax.AstTypeIntersection
		assert.eq(intersectionType.kind, "type")
		assert.eq(intersectionType.tag, "intersection")
		assert.throwsWith(frozenTableMessage, function()
			(intersectionType :: any).leading = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((intersectionType :: any).types, nil)
		end)
	end)

	suite:case("astTypeArrayFrozen", function(assert)
		local block = parser.parseblock("type Foo = {string}")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local arrayType = typeAlias.type :: syntax.AstTypeArray
		assert.eq(arrayType.kind, "type")
		assert.eq(arrayType.tag, "array")
		assert.throwsWith(frozenTableMessage, function()
			(arrayType :: any).type = nil
		end)
	end)

	suite:case("astTypeTableFrozen", function(assert)
		local block = parser.parseblock('type Foo = { a: number, [string]: boolean, ["hello"]: "world" }')
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local tableType = typeAlias.type :: syntax.AstTypeTable
		assert.eq(tableType.kind, "type")
		assert.eq(tableType.tag, "table")
		assert.throwsWith(frozenTableMessage, function()
			(tableType :: any).openbrace = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((tableType :: any).entries, nil)
		end)
		assert.throwsWith(frozenTableMessage, function()
			(tableType :: any).entries[1].kind = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			(tableType :: any).entries[2].kind = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			(tableType :: any).entries[3].kind = nil
		end)
	end)

	suite:case("astTypeFunctionFrozen", function(assert)
		local block = parser.parseblock("type Foo = (x: number) -> string")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local funcType = typeAlias.type :: syntax.AstTypeFunction
		assert.eq(funcType.kind, "type")
		assert.eq(funcType.tag, "function")
		assert.throwsWith(frozenTableMessage, function()
			(funcType :: any).returnspecifier = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			(funcType :: any).parameters[1].node.name = nil
		end)
	end)

	suite:case("astTypePackExplicitFrozen", function(assert)
		local block = parser.parseblock("type Foo = (number, string) -> (boolean, string)")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local funcType = typeAlias.type :: syntax.AstTypeFunction
		local typePack = funcType.returntypes :: syntax.AstTypePackExplicit
		assert.eq(typePack.kind, "typepack")
		assert.eq(typePack.tag, "explicit")
		assert.throwsWith(frozenTableMessage, function()
			(typePack :: any).openparens = nil
		end)
	end)

	suite:case("astTypePackVariadicFrozen", function(assert)
		local block = parser.parseblock("type Foo = () -> ...number")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local funcType = typeAlias.type :: syntax.AstTypeFunction
		local typePack = funcType.returntypes :: syntax.AstTypePackVariadic
		assert.eq(typePack.kind, "typepack")
		assert.eq(typePack.tag, "variadic")
		assert.throwsWith(frozenTableMessage, function()
			(typePack :: any).type = nil
		end)
	end)

	-- Other node types
	suite:case("astLocalFrozen", function(assert)
		local block = parser.parseblock("local x: number = 1")
		local localStat = block.statements[1] :: syntax.AstStatLocal
		local local_ = localStat.variables[1].node
		assert.eq(local_.kind, "local")
		assert.throwsWith(frozenTableMessage, function()
			(local_ :: any).name = nil
		end)
	end)

	suite:case("astGenericTypeFrozen", function(assert)
		local block = parser.parseblock("type Foo<T = number> = T")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local generic = (typeAlias.generics :: any)[1].node
		assert.eq(generic.tag, "generic")
		assert.throwsWith(frozenTableMessage, function()
			generic.name = nil
		end)
	end)

	suite:case("astGenericTypePackFrozen", function(assert)
		local block = parser.parseblock("type Foo<T, U...> = (T, U...) -> ()")
		local typeAlias = block.statements[1] :: syntax.AstStatTypeAlias
		local genericPack = (typeAlias.genericPacks :: any)[1].node
		assert.eq(genericPack.tag, "generic")
		assert.eq(genericPack.kind, "typepack")
		assert.throwsWith(frozenTableMessage, function()
			genericPack.name = nil
		end)
	end)

	-- Token type
	suite:case("tokenFrozen", function(assert)
		local block = parser.parseblock("local x = 1")
		local localStat = block.statements[1] :: syntax.AstStatLocal
		local token = localStat.localKeyword
		assert.eq(token.kind, "token")
		assert.throwsWith(frozenTableMessage, function()
			(token :: any).text = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((token :: any).leadingTrivia, nil)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((token :: any).trailingTrivia, nil)
		end)
	end)

	-- Trivia types
	suite:case("triviaFrozen", function(assert)
		local block = parser.parseblock([=[
	-- This is a comment
	--[[This is a multiline comment
		hello
	]]

	local x = 1
	]=])
		local localStat = block.statements[1] :: syntax.AstStatLocal
		local trivias = localStat.localKeyword.leadingTrivia
		for _, trivia in trivias do
			assert.throwsWith(frozenTableMessage, function()
				(trivia :: any).text = "modified"
			end)
		end
	end)

	-- ParseResult type
	suite:case("parseResultFrozen", function(assert)
		local result = parser.parse("local x = 1")
		assert.throwsWith(frozenTableMessage, function()
			(result :: any).root = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((result :: any).lineoffsets, nil)
		end)
	end)

	-- Pair type (used in Punctuated)
	suite:case("pairFrozen", function(assert)
		local block = parser.parseblock("local x, y = 1, 2")
		local localStat = block.statements[1] :: syntax.AstStatLocal
		local pair = localStat.variables[1]
		assert.throwsWith(frozenTableMessage, function()
			(pair :: any).node = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			(pair :: any).separator = nil
		end)
	end)

	-- Eof type
	suite:case("eofFrozen", function(assert)
		local result = parser.parse("local x = 1")
		local eof = result.eof
		assert.eq(eof.tag, "eof")
		assert.eq(eof.kind, "token")
		assert.throwsWith(frozenTableMessage, function()
			(eof :: any).tag = "modified"
		end)
	end)
end)
