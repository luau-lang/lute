local asserts = require("@std/assert")
local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local test = require("@std/test")

local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local T = require("@std/luau")

local function assertEqualsLocation(
	assert: asserts.Asserts,
	actual: T.Location,
	startLine: number,
	startColumn: number,
	endLine: number,
	endColumn: number
)
	assert.eq(actual.begin.line, startLine)
	assert.eq(actual.begin.column, startColumn)
	assert.eq(actual["end"].line, endLine)
	assert.eq(actual["end"].column, endColumn)
end

test.suite("Parser", function(suite)
	suite:case("tokenContainsLeadingSpaces", function(assert)
		local block = luau.parse("  local x = 1").root
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: luau.AstStatLocal).localkeyword
		assert.eq(#token.leadingtrivia, 1)
		assert.eq(token.leadingtrivia[1].tag, "whitespace")
		assert.eq(token.leadingtrivia[1].text, "  ")
		assertEqualsLocation(assert, token.leadingtrivia[1].location, 0, 0, 0, 2)
	end)

	suite:case("tokenContainsLeadingNewline", function(assert)
		local block = luau.parse("\n" .. "local x = 1").root
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: luau.AstStatLocal).localkeyword
		assert.eq(#token.leadingtrivia, 1)
		assert.eq(token.leadingtrivia[1].tag, "whitespace")
		assert.eq(token.leadingtrivia[1].text, "\n")
		assertEqualsLocation(assert, token.leadingtrivia[1].location, 0, 0, 1, 0)
	end)

	suite:case("tokenContainsLeadingSingleLineComment", function(assert)
		local block = luau.parse("-- comment\n" .. "local x = 1").root
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: luau.AstStatLocal).localkeyword
		assert.eq(#token.leadingtrivia, 2)
		assert.eq(token.leadingtrivia[1].tag, "comment")
		assert.eq(token.leadingtrivia[1].text, "-- comment")
		assertEqualsLocation(assert, token.leadingtrivia[1].location, 0, 0, 0, 10)
		assert.eq(token.leadingtrivia[2].tag, "whitespace")
		assert.eq(token.leadingtrivia[2].text, "\n")
		assertEqualsLocation(assert, token.leadingtrivia[2].location, 0, 10, 1, 0)
	end)

	suite:case("tokenContainsLeadingBlockComment", function(assert)
		local block = luau.parse("--[[ comment ]] local x = 1").root
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: luau.AstStatLocal).localkeyword
		assert.eq(#token.leadingtrivia, 2)
		assert.eq(token.leadingtrivia[1].tag, "blockcomment")
		assert.eq(token.leadingtrivia[1].text, "--[[ comment ]]")
		assertEqualsLocation(assert, token.leadingtrivia[1].location, 0, 0, 0, 15)
		assert.eq(token.leadingtrivia[2].tag, "whitespace")
		assert.eq(token.leadingtrivia[2].text, " ")
		assertEqualsLocation(assert, token.leadingtrivia[2].location, 0, 15, 0, 16)
	end)

	suite:case("tokenizeWhitespace", function(assert)
		local block = luau.parse("  \n\t\t\n\n" .. "local x = 1").root
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: luau.AstStatLocal).localkeyword
		assert.eq(#token.leadingtrivia, 3)
		assert.eq(token.leadingtrivia[1].text, "  \n")
		assert.eq(token.leadingtrivia[2].text, "\t\t\n")
		assert.eq(token.leadingtrivia[3].text, "\n")
	end)

	suite:case("triviaSplitBetweenLeadingAndTrailing", function(assert)
		local block = luau.parse("local x = 'test' -- comment\n" .. "-- comment 2\nlocal y = 'value'").root
		assert.eq(#block.statements, 2)

		local firstStmt = block.statements[1]
		assert.eq(firstStmt.tag, "local")

		local trailingToken: luau.AstExpr = (firstStmt :: luau.AstStatLocal).values[1].node
		assert.eq(trailingToken.tag, "string")
		local expr = trailingToken :: luau.AstExprConstantString
		assert.eq(#expr.trailingtrivia, 3)
		assert.eq(expr.trailingtrivia[1].text, " ")
		assert.eq(expr.trailingtrivia[2].text, "-- comment")
		assert.eq(expr.trailingtrivia[3].text, "\n")

		local secondStmt = block.statements[2]
		assert.eq(secondStmt.tag, "local")

		local leadingToken = (secondStmt :: luau.AstStatLocal).localkeyword
		assert.eq(#leadingToken.leadingtrivia, 2)
		assert.eq(leadingToken.leadingtrivia[1].text, "-- comment 2")
		assert.eq(leadingToken.leadingtrivia[2].text, "\n")
	end)

	suite:case("roundtrippableAst", function(assert)
		local function visitDirectory(directory: string)
			for _, entry in fs.listdir(directory) do
				local p = path.join(directory, entry.name)
				local source = fs.readfiletostring(path.format(p))
				local result = printer.printfile(parser.parsefile(source))

				assert.eq(source, result)
			end
		end

		visitDirectory("examples")
		visitDirectory("tests/parserExamples")
	end)

	suite:case("lineOffsetsField", function(assert)
		local singleLineCode = "local x = 1"
		local result = luau.parse(singleLineCode)

		assert.eq(type(result.lineoffsets), "table")
		assert.eq(#result.lineoffsets, 1)
		assert.eq(result.lineoffsets[1], 0)

		local multiLineCode = "local x = 1\nlocal y = 2\nlocal z = 3"
		local multiResult = luau.parse(multiLineCode)

		assert.eq(type(multiResult.lineoffsets), "table")
		assert.eq(#multiResult.lineoffsets, 3)
		assert.eq(multiResult.lineoffsets[1], 0)
		assert.eq(multiResult.lineoffsets[2], 12)
		assert.eq(multiResult.lineoffsets[3], 24)

		local emptyLineCode = "local x = 1\n\nlocal y = 2"
		local emptyResult = luau.parse(emptyLineCode)

		assert.eq(type(emptyResult.lineoffsets), "table")
		assert.eq(#emptyResult.lineoffsets, 3)
		assert.eq(emptyResult.lineoffsets[1], 0)
		assert.eq(emptyResult.lineoffsets[2], 12)
		assert.eq(emptyResult.lineoffsets[3], 13)
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

		for _, subcase in ipairs(subcases) do
			local block = luau.parse(subcase.code).root
			assert.eq(#block.statements, 1)

			local l = block.statements[1]
			assert.eq(l.tag, "localfunction")

			local lf = l :: luau.AstStatLocalFunction
			assert.eq(lf.attributes[1].text, subcase.attr)
		end
	end)
end)

test.suite("parseExpr", function(suite)
	suite:case("parseExprGroup", function(assert)
		local groupExpr = parser.parseexpr("(x)")
		assert.eq(groupExpr.tag, "group")
		assert.eq(groupExpr.kind, "expr")
		local expr = groupExpr :: luau.AstExprGroup
		assert.eq(expr.openparens.text, "(")
		assert.eq(expr.closeparens.text, ")")
		assert.eq(expr.expression.tag, "global")
	end)

	suite:case("parseExprNil", function(assert)
		local expr = parser.parseexpr("nil")
		assert.eq(expr.tag, "nil")
		assert.eq(expr.kind, "expr")
		assert.eq((expr :: luau.AstExprConstantNil).text, "nil")
	end)

	suite:case("parseExprBoolean", function(assert)
		local trueExpr = parser.parseexpr("true")
		assert.eq(trueExpr.tag, "boolean")
		assert.eq(trueExpr.kind, "expr")
		assert.eq((trueExpr :: luau.AstExprConstantBool).text, "true")
		assert.eq((trueExpr :: luau.AstExprConstantBool).value, true)

		local falseExpr = parser.parseexpr("false")
		assert.eq(falseExpr.tag, "boolean")
		assert.eq(falseExpr.kind, "expr")
		assert.eq((falseExpr :: luau.AstExprConstantBool).text, "false")
		assert.eq((falseExpr :: luau.AstExprConstantBool).value, false)
	end)

	suite:case("parseExprNumber", function(assert)
		local numberExpr = parser.parseexpr("42")
		assert.eq(numberExpr.tag, "number")
		assert.eq(numberExpr.kind, "expr")
		assert.eq((numberExpr :: luau.AstExprConstantNumber).text, "42")
		assert.eq((numberExpr :: luau.AstExprConstantNumber).value, 42)

		local floatExpr = parser.parseexpr("3.14")
		assert.eq(floatExpr.tag, "number")
		assert.eq(floatExpr.kind, "expr")
		assert.eq((floatExpr :: luau.AstExprConstantNumber).text, "3.14")
		assert.eq((floatExpr :: luau.AstExprConstantNumber).value, 3.14)
	end)

	suite:case("parseExprString", function(assert)
		local singleQuoteExpr = parser.parseexpr("'hello'")
		assert.eq(singleQuoteExpr.tag, "string")
		assert.eq(singleQuoteExpr.kind, "expr")
		assert.eq((singleQuoteExpr :: luau.AstExprConstantString).text, "hello")
		assert.eq((singleQuoteExpr :: luau.AstExprConstantString).quotestyle, "single")

		local doubleQuoteExpr = parser.parseexpr('"world"')
		assert.eq(doubleQuoteExpr.tag, "string")
		assert.eq(doubleQuoteExpr.kind, "expr")
		assert.eq((doubleQuoteExpr :: luau.AstExprConstantString).text, "world")
		assert.eq((doubleQuoteExpr :: luau.AstExprConstantString).quotestyle, "double")

		local blockQuoteExpr = parser.parseexpr("[[world]]")
		assert.eq(blockQuoteExpr.tag, "string")
		assert.eq(blockQuoteExpr.kind, "expr")
		assert.eq((blockQuoteExpr :: luau.AstExprConstantString).text, "world")
		assert.eq((blockQuoteExpr :: luau.AstExprConstantString).quotestyle, "block")

		local interpExpr = parser.parseexpr("`foobar`")
		assert.eq(interpExpr.tag, "string")
		assert.eq(interpExpr.kind, "expr")
		assert.eq((interpExpr :: luau.AstExprConstantString).text, "foobar")
		assert.eq((interpExpr :: luau.AstExprConstantString).quotestyle, "interp")
	end)

	suite:case("parseExprLocal", function(assert)
		local localExpr = parser.parseexpr("x")
		assert.eq(localExpr.tag, "global")
		assert.eq(localExpr.kind, "expr")
		assert.eq((localExpr :: luau.AstExprGlobal).name.text, "x")
	end)

	suite:case("parseExprGlobal", function(assert)
		local globalExpr = parser.parseexpr("_G")
		assert.eq(globalExpr.tag, "global")
		assert.eq(globalExpr.kind, "expr")
		assert.eq((globalExpr :: luau.AstExprGlobal).name.text, "_G")
	end)

	suite:case("parseExprVarargs", function(assert)
		local varargsExpr = parser.parseexpr("...")
		assert.eq(varargsExpr.tag, "vararg")
		assert.eq(varargsExpr.kind, "expr")
		assert.eq((varargsExpr :: luau.AstExprVarargs).text, "...")
	end)

	suite:case("parseExprCall", function(assert)
		local callExpr = parser.parseexpr("foo()")
		assert.eq(callExpr.tag, "call")
		assert.eq(callExpr.kind, "expr")
		assert.eq((callExpr :: luau.AstExprCall).func.tag, "global")
		assert.eq(((callExpr :: luau.AstExprCall).func :: luau.AstExprGlobal).name.text, "foo")
		assert.eq((callExpr :: luau.AstExprCall).self, false)
		assert.eq(#(callExpr :: luau.AstExprCall).arguments, 0)

		local callWithArgsExpr = parser.parseexpr("bar(1, 2)")
		assert.eq(callWithArgsExpr.tag, "call")
		assert.eq(callWithArgsExpr.kind, "expr")
		assert.eq(#(callWithArgsExpr :: luau.AstExprCall).arguments, 2)
		assert.eq((callWithArgsExpr :: luau.AstExprCall).arguments[1].node.tag, "number")
		assert.eq((callWithArgsExpr :: luau.AstExprCall).arguments[2].node.tag, "number")
	end)

	suite:case("parseExprIndexName", function(assert)
		local indexExpr = parser.parseexpr("obj.field")
		assert.eq(indexExpr.tag, "indexname")
		assert.eq(indexExpr.kind, "expr")
		assert.eq((indexExpr :: luau.AstExprIndexName).expression.tag, "global")
		assert.eq((indexExpr :: luau.AstExprIndexName).accessor.text, ".")
		assert.eq((indexExpr :: luau.AstExprIndexName).index.text, "field")
	end)

	suite:case("parseExprIndexExpr", function(assert)
		local indexExpr = parser.parseexpr("arr[1]")
		assert.eq(indexExpr.tag, "index")
		assert.eq(indexExpr.kind, "expr")
		assert.eq((indexExpr :: luau.AstExprIndexExpr).expression.tag, "global")
		assert.eq((indexExpr :: luau.AstExprIndexExpr).index.tag, "number")
		assert.eq((indexExpr :: luau.AstExprIndexExpr).openbrackets.text, "[")
		assert.eq((indexExpr :: luau.AstExprIndexExpr).closebrackets.text, "]")
	end)

	suite:case("parseExprAnonymousFunction", function(assert)
		local anonFuncExpr = parser.parseexpr("function(a, b) return a + b end")
		assert.eq(anonFuncExpr.tag, "function")
		assert.eq(anonFuncExpr.kind, "expr")

		local funcExpr = anonFuncExpr :: luau.AstExprAnonymousFunction
		assert.eq(#funcExpr.attributes, 0)
		assert.eq(funcExpr.functionkeyword.text, "function")

		local funcBody = funcExpr.body
		assert.eq(funcBody.opengenerics, nil)
		assert.eq(funcBody.generics, nil)
		assert.eq(funcBody.genericpacks, nil)
		assert.eq(funcBody.closegenerics, nil)
		assert.eq(funcBody.self, nil)
		assert.eq(funcBody.openparens.text, "(")
		assert.eq(#funcBody.parameters, 2)
		assert.eq(funcBody.parameters[1].node.name.text, "a")
		assert.eq(funcBody.parameters[2].node.name.text, "b")
		assert.eq(funcBody.vararg, nil)
		assert.eq(funcBody.varargcolon, nil)
		assert.eq(funcBody.varargannotation, nil)
		assert.eq(funcBody.closeparens.text, ")")
		assert.eq(funcBody.returnspecifier, nil)
		assert.eq(funcBody.returnannotation, nil)
		assert.eq(funcBody.endkeyword.text, "end")

		anonFuncExpr = parser.parseexpr("function<A, B...>(a: A, ...: B...): A return a end")
		assert.eq(anonFuncExpr.tag, "function")
		assert.eq(anonFuncExpr.kind, "expr")

		funcExpr = anonFuncExpr :: luau.AstExprAnonymousFunction
		assert.eq(#funcExpr.attributes, 0)
		assert.eq(funcExpr.functionkeyword.text, "function")

		funcBody = funcExpr.body
		assert.neq(funcBody.opengenerics, nil)
		assert.neq(funcBody.generics, nil)

		assert.eq(#funcBody.generics :: luau.Punctuated<luau.AstGenericType>, 1)
		local gen = (funcBody.generics :: luau.Punctuated<luau.AstGenericType>)[1].node
		assert.eq(gen.name.text, "A")
		assert.eq(gen.equals, nil)
		assert.eq(gen.default, nil)

		assert.neq(funcBody.genericpacks, nil)
		assert.eq(#funcBody.genericpacks :: luau.Punctuated<luau.AstGenericTypePack>, 1)
		local genPack = (funcBody.genericpacks :: luau.Punctuated<luau.AstGenericTypePack>)[1].node
		assert.eq(genPack.name.text, "B")
		assert.eq(genPack.ellipsis.text, "...")
		assert.eq(genPack.equals, nil)
		assert.eq(genPack.default, nil)

		assert.neq(funcBody.closegenerics, nil)
		assert.eq((funcBody.closegenerics :: luau.Token<">">).text, ">")

		assert.eq(funcBody.openparens.text, "(")
		assert.eq(#funcBody.parameters, 1)

		local param = funcBody.parameters[1].node
		assert.eq(param.name.text, "a")
		assert.neq(param.colon, nil)
		assert.eq((param.colon :: luau.Token<":">).text, ":")
		assert.neq(param.annotation, nil)
		assert.eq((param.annotation :: luau.AstType).tag, "reference")

		assert.neq(funcBody.vararg, nil)
		assert.eq((funcBody.vararg :: luau.Token<"...">).text, "...")
		assert.neq(funcBody.varargcolon, nil)
		assert.eq((funcBody.varargcolon :: luau.Token<":">).text, ":")
		assert.neq(funcBody.varargannotation, nil)
		assert.eq((funcBody.varargannotation :: luau.AstTypePack).tag, "generic")

		assert.eq(funcBody.closeparens.text, ")")
		assert.neq(funcBody.returnspecifier, nil)
		assert.eq((funcBody.returnspecifier :: luau.Token<":">).text, ":")
		assert.neq(funcBody.returnannotation, nil)
		assert.eq((funcBody.returnannotation :: luau.AstTypePack).tag, "explicit")
	end)

	suite:case("parseExprTable", function(assert)
		local emptyTableExpr = parser.parseexpr("{}")
		assert.eq(emptyTableExpr.tag, "table")
		assert.eq(emptyTableExpr.kind, "expr")
		local tableExpr = emptyTableExpr :: luau.AstExprTable
		assert.eq(tableExpr.openbrace.text, "{")
		assert.eq(tableExpr.closebrace.text, "}")
		assert.eq(#tableExpr.entries, 0)

		local mixedTable = parser.parseexpr("{1, foo = bar; [2] = baz}")
		assert.eq(mixedTable.tag, "table")
		assert.eq(mixedTable.kind, "expr")
		local mixedTableExpr = mixedTable :: luau.AstExprTable
		assert.eq(#mixedTableExpr.entries, 3)

		local entry1 = mixedTableExpr.entries[1]
		assert.eq(entry1.kind, "list")
		assert.eq(entry1.value.tag, "number")
		assert.neq(entry1.separator, nil)
		assert.eq((entry1.separator :: luau.Token<"," | ";">).text, ",")

		local entry2: any = mixedTableExpr.entries[2]
		assert.eq(entry2.kind, "record")
		assert.eq(entry2.key.text, "foo")
		assert.eq(entry2.equals.text, "=")
		assert.eq(entry2.value.tag, "global")
		assert.neq(entry2.separator, nil)
		assert.eq((entry2.separator :: luau.Token<"," | ";">).text, ";")

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
		local expr = notExpr :: luau.AstExprUnary
		assert.eq(expr.operator.text, "not")
		assert.eq(expr.operand.tag, "global")

		local negExpr = parser.parseexpr("-42")
		assert.eq(negExpr.tag, "unary")
		assert.eq(negExpr.kind, "expr")
		expr = negExpr :: luau.AstExprUnary
		assert.eq(expr.operator.text, "-")
		assert.eq(expr.operand.tag, "number")

		local lenExpr = parser.parseexpr("#str")
		assert.eq(lenExpr.tag, "unary")
		assert.eq(lenExpr.kind, "expr")
		expr = lenExpr :: luau.AstExprUnary
		assert.eq(expr.operator.text, "#")
		assert.eq(expr.operand.tag, "global")
	end)

	suite:case("parseExprBinary", function(assert)
		local addExpr = parser.parseexpr("1 + 2")
		assert.eq(addExpr.tag, "binary")
		assert.eq(addExpr.kind, "expr")
		local expr = addExpr :: luau.AstExprBinary
		assert.eq(expr.lhsoperand.tag, "number")
		assert.eq(expr.operator.text, "+")
		assert.eq(expr.rhsoperand.tag, "number")
	end)

	suite:case("parseExprInterpString", function(assert)
		local interpExpr = parser.parseexpr("`Hello, {name}! Today is {dayOfWeek}.`")
		assert.eq(interpExpr.tag, "interpolatedstring")
		assert.eq(interpExpr.kind, "expr")
		local expr = interpExpr :: luau.AstExprInterpString
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
		local expr = castExpr :: luau.AstExprTypeAssertion
		assert.eq(expr.operand.tag, "global")
		assert.eq(expr.operator.text, "::")
		assert.eq(expr.annotation.tag, "reference")
	end)
end)

test.run()
