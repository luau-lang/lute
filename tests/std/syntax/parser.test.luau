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
		local block = parser.parseBlock("  local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.CstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 1)
		assert.eq(token.leadingTrivia[1].tag, "whitespace")
		assert.eq(token.leadingTrivia[1].text, "  ")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 1, 3)
	end)

	suite:case("tokenContainsLeadingNewline", function(assert)
		local block = parser.parseBlock("\n" .. "local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.CstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 1)
		assert.eq(token.leadingTrivia[1].tag, "whitespace")
		assert.eq(token.leadingTrivia[1].text, "\n")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 2, 1)
	end)

	suite:case("tokenContainsLeadingSingleLineComment", function(assert)
		local block = parser.parseBlock("-- comment\n" .. "local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.CstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 2)
		assert.eq(token.leadingTrivia[1].tag, "comment")
		assert.eq(token.leadingTrivia[1].text, "-- comment")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 1, 11)
		assert.eq(token.leadingTrivia[2].tag, "whitespace")
		assert.eq(token.leadingTrivia[2].text, "\n")
		assertEqualsLocation(assert, token.leadingTrivia[2].location, 1, 11, 2, 1)
	end)

	suite:case("tokenContainsLeadingBlockComment", function(assert)
		local block = parser.parseBlock("--[[ comment ]] local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.CstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 2)
		assert.eq(token.leadingTrivia[1].tag, "blockcomment")
		assert.eq(token.leadingTrivia[1].text, "--[[ comment ]]")
		assertEqualsLocation(assert, token.leadingTrivia[1].location, 1, 1, 1, 16)
		assert.eq(token.leadingTrivia[2].tag, "whitespace")
		assert.eq(token.leadingTrivia[2].text, " ")
		assertEqualsLocation(assert, token.leadingTrivia[2].location, 1, 16, 1, 17)
	end)

	suite:case("tokenizeWhitespace", function(assert)
		local block = parser.parseBlock("  \n\t\t\n\n" .. "local x = 1")
		assert.eq(#block.statements, 1)

		local l = block.statements[1]
		assert.eq(l.tag, "local")

		local token = (l :: syntax.CstStatLocal).localKeyword
		assert.eq(#token.leadingTrivia, 3)
		assert.eq(token.leadingTrivia[1].text, "  \n")
		assert.eq(token.leadingTrivia[2].text, "\t\t\n")
		assert.eq(token.leadingTrivia[3].text, "\n")
	end)

	suite:case("triviaSplitBetweenLeadingAndTrailing", function(assert)
		local block = parser.parseBlock("local x = 'test' -- comment\n" .. "-- comment 2\nlocal y = 'value'")
		assert.eq(#block.statements, 2)

		local firstStmt = block.statements[1]
		assert.eq(firstStmt.tag, "local")

		local trailingToken: syntax.CstExpr = (firstStmt :: syntax.CstStatLocal).values[1]
		assert.eq(trailingToken.tag, "string")
		local expr = trailingToken :: syntax.CstExprConstantString
		assert.eq(#expr.value.trailingTrivia, 3)
		assert.eq(expr.value.trailingTrivia[1].text, " ")
		assert.eq(expr.value.trailingTrivia[2].text, "-- comment")
		assert.eq(expr.value.trailingTrivia[3].text, "\n")

		local secondStmt = block.statements[2]
		assert.eq(secondStmt.tag, "local")

		local leadingToken = (secondStmt :: syntax.CstStatLocal).localKeyword
		assert.eq(#leadingToken.leadingTrivia, 2)
		assert.eq(leadingToken.leadingTrivia[1].text, "-- comment 2")
		assert.eq(leadingToken.leadingTrivia[2].text, "\n")
	end)

	local function visitDirectory(directory: string)
		for _, entry in fs.listDirectory(directory) do
			if entry.type ~= "file" then
				continue
			end
			if not strext.hasSuffix(entry.name, ".luau") then
				continue
			end

			suite:case(`roundtrippable_Cst_{entry.name}`, function(assert)
				local p = path.join(directory, entry.name)
				local source = fs.readFileToString(path.format(p))
				local result = printer.printFile(parser.parse(source))

				assert.eq(source, result)
			end)
		end
	end

	visitDirectory("examples")
	visitDirectory("tests/parserExamples")

	suite:case("lineOffsetsField", function(assert)
		local singleLineCode = "local x = 1"
		local result = parser.parse(singleLineCode)

		assert.eq(type(result.lineOffsets), "table")
		assert.eq(#result.lineOffsets, 1)
		assert.eq(result.lineOffsets[1], 1)

		local multiLineCode = "local x = 1\nlocal y = 2\nlocal z = 3"
		local multiResult = parser.parse(multiLineCode)

		assert.eq(type(multiResult.lineOffsets), "table")
		assert.eq(#multiResult.lineOffsets, 3)
		assert.eq(multiResult.lineOffsets[1], 1)
		assert.eq(multiResult.lineOffsets[2], 13)
		assert.eq(multiResult.lineOffsets[3], 25)

		local emptyLineCode = "local x = 1\n\nlocal y = 2"
		local emptyResult = parser.parse(emptyLineCode)

		assert.eq(type(emptyResult.lineOffsets), "table")
		assert.eq(#emptyResult.lineOffsets, 3)
		assert.eq(emptyResult.lineOffsets[1], 1)
		assert.eq(emptyResult.lineOffsets[2], 13)
		assert.eq(emptyResult.lineOffsets[3], 14)
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
			local block = parser.parseBlock(subcase.code)
			assert.eq(#block.statements, 1)

			local l = block.statements[1]
			assert.eq(l.tag, "localfunction")

			local lf = l :: syntax.CstStatLocalFunction
			assert.eq(lf.func.attributes[1].name.text, subcase.attr)
		end
	end)
end)

test.suite("parseExpr", function(suite)
	suite:case("parseExprGroup", function(assert)
		local groupExpr = parser.parseExpr("(x)")
		assert.eq(groupExpr.tag, "group")
		assert.eq(groupExpr.kind, "expr")
		local expr = groupExpr :: syntax.CstExprGroup
		assert.eq(expr.openParens.text, "(")
		assert.eq(expr.closeParens.text, ")")
		assert.eq(expr.expression.tag, "global")
	end)

	suite:case("parseExprNil", function(assert)
		local expr = parser.parseExpr("nil")
		assert.eq(expr.tag, "nil")
		assert.eq(expr.kind, "expr")
		assert.eq((expr :: syntax.CstExprConstantNil).token.text, "nil")
	end)

	suite:case("parseExprBoolean", function(assert)
		local trueExpr = parser.parseExpr("true")
		assert.eq(trueExpr.tag, "boolean")
		assert.eq(trueExpr.kind, "expr")
		assert.eq((trueExpr :: syntax.CstExprConstantBool).token.text, "true")
		assert.that((trueExpr :: syntax.CstExprConstantBool).value)

		local falseExpr = parser.parseExpr("false")
		assert.eq(falseExpr.tag, "boolean")
		assert.eq(falseExpr.kind, "expr")
		assert.eq((falseExpr :: syntax.CstExprConstantBool).token.text, "false")
		assert.eq((falseExpr :: syntax.CstExprConstantBool).value, false)
	end)

	suite:case("parseExprNumber", function(assert)
		local numberExpr = parser.parseExpr("42")
		assert.eq(numberExpr.tag, "number")
		assert.eq(numberExpr.kind, "expr")
		assert.eq((numberExpr :: syntax.CstExprConstantNumber).token.text, "42")
		assert.eq((numberExpr :: syntax.CstExprConstantNumber).value, 42)

		local floatExpr = parser.parseExpr("3.14")
		assert.eq(floatExpr.tag, "number")
		assert.eq(floatExpr.kind, "expr")
		assert.eq((floatExpr :: syntax.CstExprConstantNumber).token.text, "3.14")
		assert.eq((floatExpr :: syntax.CstExprConstantNumber).value, 3.14)
	end)

	suite:case("parseExprInteger", function(assert)
		local numberExpr = parser.parseExpr("42i")
		assert.eq(numberExpr.tag, "integer")
		assert.eq(numberExpr.kind, "expr")
		assert.eq((numberExpr :: syntax.CstExprConstantInteger).token.text, "42i")
		assert.eq((numberExpr :: syntax.CstExprConstantInteger).value, 42)
	end)

	suite:case("parseExprString", function(assert)
		local singleQuoteExpr = parser.parseExpr("'hello'")
		assert.eq(singleQuoteExpr.tag, "string")
		assert.eq(singleQuoteExpr.kind, "expr")
		assert.eq((singleQuoteExpr :: syntax.CstExprConstantString).value.text, "hello")
		assert.eq((singleQuoteExpr :: syntax.CstExprConstantString).quoteStyle, "single")

		local doubleQuoteExpr = parser.parseExpr('"world"')
		assert.eq(doubleQuoteExpr.tag, "string")
		assert.eq(doubleQuoteExpr.kind, "expr")
		assert.eq((doubleQuoteExpr :: syntax.CstExprConstantString).value.text, "world")
		assert.eq((doubleQuoteExpr :: syntax.CstExprConstantString).quoteStyle, "double")

		local blockQuoteExpr = parser.parseExpr("[[world]]")
		assert.eq(blockQuoteExpr.tag, "string")
		assert.eq(blockQuoteExpr.kind, "expr")
		assert.eq((blockQuoteExpr :: syntax.CstExprConstantString).value.text, "world")
		assert.eq((blockQuoteExpr :: syntax.CstExprConstantString).quoteStyle, "block")

		local interpExpr = parser.parseExpr("`foobar`")
		assert.eq(interpExpr.tag, "string")
		assert.eq(interpExpr.kind, "expr")
		assert.eq((interpExpr :: syntax.CstExprConstantString).value.text, "foobar")
		assert.eq((interpExpr :: syntax.CstExprConstantString).quoteStyle, "interp")
	end)

	suite:case("parseExprLocal", function(assert)
		local localExpr = parser.parseExpr("x")
		assert.eq(localExpr.tag, "global")
		assert.eq(localExpr.kind, "expr")
		assert.eq((localExpr :: syntax.CstExprGlobal).name.text, "x")
	end)

	suite:case("parseExprGlobal", function(assert)
		local globalExpr = parser.parseExpr("_G")
		assert.eq(globalExpr.tag, "global")
		assert.eq(globalExpr.kind, "expr")
		assert.eq((globalExpr :: syntax.CstExprGlobal).name.text, "_G")
	end)

	suite:case("parseExprVarargs", function(assert)
		local varargsExpr = parser.parseExpr("...")
		assert.eq(varargsExpr.tag, "vararg")
		assert.eq(varargsExpr.kind, "expr")
		assert.eq((varargsExpr :: syntax.CstExprVarargs).token.text, "...")
	end)

	suite:case("parseExprCall", function(assert)
		local callExpr = parser.parseExpr("foo()")
		assert.eq(callExpr.tag, "call")
		assert.eq(callExpr.kind, "expr")
		assert.eq((callExpr :: syntax.CstExprCall).func.tag, "global")
		assert.eq(((callExpr :: syntax.CstExprCall).func :: syntax.CstExprGlobal).name.text, "foo")
		assert.eq((callExpr :: syntax.CstExprCall).self, false)
		assert.eq(#(callExpr :: syntax.CstExprCall).arguments, 0)

		local callWithArgsExpr = parser.parseExpr("bar(1, 2)")
		assert.eq(callWithArgsExpr.tag, "call")
		assert.eq(callWithArgsExpr.kind, "expr")
		assert.eq(#(callWithArgsExpr :: syntax.CstExprCall).arguments, 2)
		assert.eq((callWithArgsExpr :: syntax.CstExprCall).arguments[1].tag, "number")
		assert.eq((callWithArgsExpr :: syntax.CstExprCall).arguments[2].tag, "number")
	end)

	suite:case("parseExprInstantiate", function(assert)
		local callExpr = parser.parseExpr("foo<<string, ...number>>()")
		assert.eq(callExpr.kind, "expr")
		assert.eq(callExpr.tag, "call")

		local instExpr = (callExpr :: syntax.CstExprCall).func
		assert.eq(instExpr.tag, "instantiate")
		assert.eq(instExpr.kind, "expr")
		assert.eq((instExpr :: syntax.CstExprInstantiate).expr.tag, "global")
		assert.eq((instExpr :: syntax.CstExprInstantiate).leftArrow1.text, "<")
		assert.eq((instExpr :: syntax.CstExprInstantiate).leftArrow2.text, "<")
		assert.eq(#(instExpr :: syntax.CstExprInstantiate).typeArguments, 2)
		assert.eq(((instExpr :: syntax.CstExprInstantiate).typeArguments[1]).kind, "type")
		assert.eq(((instExpr :: syntax.CstExprInstantiate).typeArguments[1]).tag, "reference")
		assert.eq(((instExpr :: syntax.CstExprInstantiate).typeArguments[2]).kind, "typepack")
		assert.eq(((instExpr :: syntax.CstExprInstantiate).typeArguments[2]).tag, "variadic")
		assert.eq((instExpr :: syntax.CstExprInstantiate).rightArrow1.text, ">")
		assert.eq((instExpr :: syntax.CstExprInstantiate).rightArrow2.text, ">")
	end)

	suite:case("parseExprIndexName", function(assert)
		local indexExpr = parser.parseExpr("obj.field")
		assert.eq(indexExpr.tag, "indexname")
		assert.eq(indexExpr.kind, "expr")
		assert.eq((indexExpr :: syntax.CstExprIndexName).expression.tag, "global")
		assert.eq((indexExpr :: syntax.CstExprIndexName).accessor.text, ".")
		assert.eq((indexExpr :: syntax.CstExprIndexName).index.text, "field")
	end)

	suite:case("parseExprIndexExpr", function(assert)
		local indexExpr = parser.parseExpr("arr[1]")
		assert.eq(indexExpr.tag, "index")
		assert.eq(indexExpr.kind, "expr")
		assert.eq((indexExpr :: syntax.CstExprIndexExpr).expression.tag, "global")
		assert.eq((indexExpr :: syntax.CstExprIndexExpr).index.tag, "number")
		assert.eq((indexExpr :: syntax.CstExprIndexExpr).openBrackets.text, "[")
		assert.eq((indexExpr :: syntax.CstExprIndexExpr).closeBrackets.text, "]")
	end)

	suite:case("parseExprFunction", function(assert)
		local anonFuncExpr = parser.parseExpr("function(a, b) return a + b end")
		assert.eq(anonFuncExpr.tag, "function")
		assert.eq(anonFuncExpr.kind, "expr")

		local funcExpr = anonFuncExpr :: syntax.CstExprFunction
		assert.eq(#funcExpr.attributes, 0)
		assert.eq(funcExpr.functionKeyword.text, "function")
		assert.eq(funcExpr.openGenerics, nil)
		assert.eq(#funcExpr.generics, 0)
		assert.eq(#funcExpr.genericPacks, 0)
		assert.eq(funcExpr.closeGenerics, nil)
		assert.eq(funcExpr.self, nil)
		assert.eq(funcExpr.openParens.text, "(")
		assert.eq(#funcExpr.parameters, 2)
		assert.eq(funcExpr.parameters[1].name.text, "a")
		assert.eq(funcExpr.parameters[2].name.text, "b")
		assert.eq(funcExpr.hasVararg, false)
		assert.eq(funcExpr.vararg, nil)
		assert.eq(funcExpr.varargColon, nil)
		assert.eq(funcExpr.varargAnnotation, nil)
		assert.eq(funcExpr.closeParens.text, ")")
		assert.eq(funcExpr.returnSpecifier, nil)
		assert.eq(funcExpr.returnAnnotation, nil)
		assert.eq(funcExpr.endKeyword.text, "end")

		anonFuncExpr = parser.parseExpr("function<A, B...>(a: A, ...: B...): A return a end")
		assert.eq(anonFuncExpr.tag, "function")
		assert.eq(anonFuncExpr.kind, "expr")

		funcExpr = anonFuncExpr :: syntax.CstExprFunction
		assert.eq(#funcExpr.attributes, 0)
		assert.eq(funcExpr.functionKeyword.text, "function")

		assert.neq(funcExpr.openGenerics, nil)
		assert.neq(funcExpr.generics, nil)

		assert.eq(#funcExpr.generics :: syntax.CstPunctuated<syntax.CstGenericType>, 1)
		local gen = (funcExpr.generics :: syntax.CstPunctuated<syntax.CstGenericType>)[1]
		assert.eq(gen.name.text, "A")
		assert.eq(gen.equals, nil)
		assert.eq(gen.default, nil)

		assert.neq(funcExpr.genericPacks, nil)
		assert.eq(#funcExpr.genericPacks :: syntax.CstPunctuated<syntax.CstGenericTypePack>, 1)

		local genPack = (funcExpr.genericPacks :: syntax.CstPunctuated<syntax.CstGenericTypePack>)[1]
		assert.eq(genPack.name.text, "B")
		assert.eq(genPack.ellipsis.text, "...")
		assert.eq(genPack.equals, nil)
		assert.eq(genPack.default, nil)

		assert.neq(funcExpr.closeGenerics, nil)
		assert.eq((funcExpr.closeGenerics :: syntax.CstToken<">">).text, ">")

		assert.eq(funcExpr.openParens.text, "(")
		assert.eq(#funcExpr.parameters, 1)
		local param = funcExpr.parameters[1]
		assert.eq(param.name.text, "a")
		assert.neq(param.colon, nil)
		assert.eq((param.colon :: syntax.CstToken<":">).text, ":")
		assert.neq(param.annotation, nil)
		assert.eq((param.annotation :: syntax.CstType).tag, "reference")

		assert.eq(funcExpr.hasVararg, true)
		assert.neq(funcExpr.vararg, nil)
		assert.eq((funcExpr.vararg :: syntax.CstToken<"...">).text, "...")
		assert.neq(funcExpr.varargColon, nil)
		assert.eq((funcExpr.varargColon :: syntax.CstToken<":">).text, ":")
		assert.neq(funcExpr.varargAnnotation, nil)
		assert.eq((funcExpr.varargAnnotation :: syntax.CstTypePack).tag, "generic")

		assert.eq(funcExpr.closeParens.text, ")")
		assert.neq(funcExpr.returnSpecifier, nil)
		assert.eq((funcExpr.returnSpecifier :: syntax.CstToken<":">).text, ":")
		assert.neq(funcExpr.returnAnnotation, nil)
		assert.eq((funcExpr.returnAnnotation :: syntax.CstTypePack).tag, "explicit")
	end)

	suite:case("parseExprTable", function(assert)
		local emptyTableExpr = parser.parseExpr("{}")
		assert.eq(emptyTableExpr.tag, "table")
		assert.eq(emptyTableExpr.kind, "expr")
		local tableExpr = emptyTableExpr :: syntax.CstExprTable
		assert.eq(tableExpr.openBrace.text, "{")
		assert.eq(tableExpr.closeBrace.text, "}")
		assert.eq(#tableExpr.entries, 0)

		local mixedTable = parser.parseExpr("{1, foo = bar; [2] = baz}")
		assert.eq(mixedTable.tag, "table")
		assert.eq(mixedTable.kind, "expr")
		local mixedTableExpr = mixedTable :: syntax.CstExprTable
		assert.eq(#mixedTableExpr.entries, 3)

		local entry1 = mixedTableExpr.entries[1]
		assert.eq(entry1.kind, "list")
		assert.eq(entry1.value.tag, "number")
		assert.neq(entry1.separator, nil)
		assert.eq((entry1.separator :: syntax.CstToken<"," | ";">).text, ",")

		local entry2: any = mixedTableExpr.entries[2]
		assert.eq(entry2.kind, "record")
		assert.eq(entry2.key.text, "foo")
		assert.eq(entry2.equals.text, "=")
		assert.eq(entry2.value.tag, "global")
		assert.neq(entry2.separator, nil)
		assert.eq((entry2.separator :: syntax.CstToken<"," | ";">).text, ";")

		local entry3: any = mixedTableExpr.entries[3]
		assert.eq(entry3.kind, "general")
		assert.eq(entry3.indexerOpen.text, "[")
		assert.eq(entry3.key.tag, "number")
		assert.eq(entry3.indexerClose.text, "]")
		assert.eq(entry3.equals.text, "=")
		assert.eq(entry3.value.tag, "global")
		assert.eq(entry3.separator, nil)
	end)

	suite:case("parseExprTableSeparators", function(assert)
		-- Single item, no trailing separator: must not crash
		local singleItem = parser.parseExpr("{a = 1}") :: syntax.CstExprTable
		assert.eq(#singleItem.entries, 1)
		assert.eq(singleItem.entries[1].separator, nil)

		-- Comma separator must be preserved (Comma must not be treated as falsy)
		local commaSep = parser.parseExpr("{1, 2}") :: syntax.CstExprTable
		assert.eq(#commaSep.entries, 2)
		assert.neq(commaSep.entries[1].separator, nil)
		assert.eq((commaSep.entries[1].separator :: syntax.CstToken<",">).text, ",")
		assert.eq(commaSep.entries[2].separator, nil)

		-- Semicolon separator must be preserved
		local semiSep = parser.parseExpr("{1; 2}") :: syntax.CstExprTable
		assert.eq(#semiSep.entries, 2)
		assert.neq(semiSep.entries[1].separator, nil)
		assert.eq((semiSep.entries[1].separator :: syntax.CstToken<";">).text, ";")
		assert.eq(semiSep.entries[2].separator, nil)
	end)

	suite:case("parseExprUnary", function(assert)
		local notExpr = parser.parseExpr("not x")
		assert.eq(notExpr.tag, "unary")
		assert.eq(notExpr.kind, "expr")
		local expr = notExpr :: syntax.CstExprUnary
		assert.eq(expr.operator.text, "not")
		assert.eq(expr.operand.tag, "global")

		local negExpr = parser.parseExpr("-42")
		assert.eq(negExpr.tag, "unary")
		assert.eq(negExpr.kind, "expr")
		expr = negExpr :: syntax.CstExprUnary
		assert.eq(expr.operator.text, "-")
		assert.eq(expr.operand.tag, "number")

		local lenExpr = parser.parseExpr("#str")
		assert.eq(lenExpr.tag, "unary")
		assert.eq(lenExpr.kind, "expr")
		expr = lenExpr :: syntax.CstExprUnary
		assert.eq(expr.operator.text, "#")
		assert.eq(expr.operand.tag, "global")
	end)

	suite:case("parseExprBinary", function(assert)
		local addExpr = parser.parseExpr("1 + 2")
		assert.eq(addExpr.tag, "binary")
		assert.eq(addExpr.kind, "expr")
		local expr = addExpr :: syntax.CstExprBinary
		assert.eq(expr.lhsOperand.tag, "number")
		assert.eq(expr.operator.text, "+")
		assert.eq(expr.rhsOperand.tag, "number")
	end)

	suite:case("parseExprInterpString", function(assert)
		local interpExpr = parser.parseExpr("`Hello, {name}! Today is {dayOfWeek}.`")
		assert.eq(interpExpr.tag, "interpolatedstring")
		assert.eq(interpExpr.kind, "expr")
		local expr = interpExpr :: syntax.CstExprInterpString
		assert.eq(#expr.strings, 3)

		assert.eq(expr.strings[1].text, "Hello, ")
		assert.eq(expr.strings[2].text, "! Today is ")
		assert.eq(expr.strings[3].text, ".")

		assert.eq(#expr.expressions, 2)
		assert.eq(expr.expressions[1].tag, "global")
		assert.eq(expr.expressions[2].tag, "global")
	end)

	suite:case("parseExprTypeAssertion", function(assert)
		local castExpr = parser.parseExpr("x :: string")
		assert.eq(castExpr.tag, "cast")
		assert.eq(castExpr.kind, "expr")
		local expr = castExpr :: syntax.CstExprTypeAssertion
		assert.eq(expr.operand.tag, "global")
		assert.eq(expr.operator.text, "::")
		assert.eq(expr.annotation.tag, "reference")
	end)

	-- table items serialized with location field
	suite:case("exprTableItemSerializedWithLocationField", function(assert)
		local tableExpr = parser.parseExpr([[
{
1,
foo = bar,
[2] = baz 
}
		]])
		assert.eq(tableExpr.tag, "table")
		assert.eq(tableExpr.kind, "expr")
		tableExpr = tableExpr :: syntax.CstExprTable
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
		local block = parser.parseBlock("")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 0)
	end)

	suite:case("parseDoStatement", function(assert)
		local block = parser.parseBlock("do print('Hello, World!') end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local doStat = block.statements[1] :: syntax.CstStatDo
		assert.eq(doStat.tag, "do")
		assert.eq(doStat.doKeyword.text, "do")
		checkIsBlock(doStat.body, assert)
		assert.eq(#doStat.body.statements, 1)
		assert.eq(doStat.endKeyword.text, "end")
	end)

	suite:case("parseIfStatement", function(assert)
		local block = parser.parseBlock(
			"if x > 0 then print('positive') elseif x < 0 then print('negative') else print('zero') end"
		)
		assert.eq(#block.statements, 1)

		local ifStat = block.statements[1] :: syntax.CstStatIf
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
		assert.eq((ifStat.elseKeyword :: syntax.CstToken<"else">).text, "else")
		assert.neq(ifStat.elseBlock, nil)
		checkIsBlock(ifStat.elseBlock, assert)
		assert.eq(ifStat.endKeyword.text, "end")

		block = parser.parseBlock("if condition then doSomething() end")
		assert.eq(#block.statements, 1)
		local simpleIfStat = block.statements[1] :: syntax.CstStatIf
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
		local block = parser.parseBlock("while i <= 10 do print(i); i = i + 1 end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local whileStat = block.statements[1] :: syntax.CstStatWhile
		assert.eq(whileStat.tag, "while")
		assert.eq(whileStat.whileKeyword.text, "while")
		assert.eq(whileStat.condition.tag, "binary")
		assert.eq(whileStat.doKeyword.text, "do")
		checkIsBlock(whileStat.body, assert)
		assert.eq(#whileStat.body.statements, 2)
		assert.eq(whileStat.endKeyword.text, "end")

		block = parser.parseBlock("while true do break end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		whileStat = block.statements[1] :: syntax.CstStatWhile
		assert.eq(whileStat.tag, "while")
		assert.eq(whileStat.whileKeyword.text, "while")
		assert.eq(whileStat.condition.tag, "boolean")
		assert.eq(whileStat.doKeyword.text, "do")
		checkIsBlock(whileStat.body, assert)
		assert.eq(#whileStat.body.statements, 1)

		local breakStat = whileStat.body.statements[1] :: syntax.CstStat
		assert.eq(breakStat.kind, "stat")
		breakStat = breakStat :: syntax.CstStatBreak
		assert.eq(breakStat.tag, "break")
		assert.eq(breakStat.token.text, "break")

		assert.eq(whileStat.endKeyword.text, "end")

		block = parser.parseBlock("while true do continue end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		whileStat = block.statements[1] :: syntax.CstStatWhile
		assert.eq(whileStat.tag, "while")
		assert.eq(whileStat.whileKeyword.text, "while")
		assert.eq(whileStat.condition.tag, "boolean")
		assert.eq(whileStat.doKeyword.text, "do")
		checkIsBlock(whileStat.body, assert)
		assert.eq(#whileStat.body.statements, 1)

		local continueStat = whileStat.body.statements[1] :: syntax.CstStat
		assert.eq(continueStat.kind, "stat")
		continueStat = continueStat :: syntax.CstStatContinue
		assert.eq(continueStat.tag, "continue")
		assert.eq(continueStat.token.text, "continue")

		assert.eq(whileStat.endKeyword.text, "end")
	end)

	suite:case("parseStatRepeat", function(assert)
		local block = parser.parseBlock("repeat i = i + 1; print(i) until i > 5")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local repeatStat = block.statements[1] :: syntax.CstStatRepeat
		assert.eq(repeatStat.tag, "repeat")
		assert.eq(repeatStat.repeatKeyword.text, "repeat")
		checkIsBlock(repeatStat.body, assert)
		assert.eq(#repeatStat.body.statements, 2)
		assert.eq(repeatStat.untilKeyword.text, "until")
		assert.eq(repeatStat.condition.tag, "binary")
	end)

	suite:case("parseStatLocal", function(assert)
		local block = parser.parseBlock("local b, c = 1, 2")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)
		assert.eq(block.statements[1].kind, "stat")

		local l = block.statements[1] :: syntax.CstStatLocal
		assert.eq(l.tag, "local")
		assert.eq(l.localKeyword.text, "local")
		assert.eq(#l.variables, 2)
		assert.eq(l.variables[1].name.text, "b")
		assert.neq(l.variables.separators[1], nil)
		assert.eq((l.variables.separators[1] :: syntax.CstToken<",">).text, ",")
		assert.eq(l.variables[2].name.text, "c")
		assert.eq(l.variables.separators[2], nil)
		assert.neq(l.equals, nil)
		assert.eq((l.equals :: syntax.CstToken<"=">).text, "=")
		assert.eq(#l.values, 2)
		assert.eq(l.values[1].tag, "number")
		assert.neq(l.values.separators[1], nil)
		assert.eq((l.values.separators[1] :: syntax.CstToken<",">).text, ",")
		assert.eq(l.values[2].tag, "number")
		assert.eq(l.values.separators[2], nil)

		block = parser.parseBlock("local x")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)
		assert.eq(block.statements[1].kind, "stat")

		l = block.statements[1] :: syntax.CstStatLocal
		assert.eq(l.tag, "local")
		assert.eq(l.localKeyword.text, "local")
		assert.eq(#l.variables, 1)
		assert.eq(l.variables[1].name.text, "x")
		assert.eq(l.variables.separators[1], nil)
		assert.eq(l.equals, nil)
		assert.eq(#l.values, 0)
	end)

	suite:case("parseStatFor", function(assert)
		local block = parser.parseBlock("for i = 1, 10, 2 do print(i) end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local forStat = block.statements[1] :: syntax.CstStatFor
		assert.eq(forStat.tag, "for")
		assert.eq(forStat.forKeyword.text, "for")
		assert.eq(forStat.variable.name.text, "i")
		assert.eq(forStat.equals.text, "=")
		assert.eq(forStat.from.tag, "number")
		assert.eq(forStat.toComma.text, ",")
		assert.eq(forStat.to.tag, "number")
		assert.neq(forStat.stepComma, nil)
		assert.eq((forStat.stepComma :: syntax.CstToken<",">).text, ",")
		assert.neq(forStat.step, nil)
		assert.eq(((forStat.step :: any) :: syntax.CstExpr).tag, "number")
		assert.eq(forStat.doKeyword.text, "do")
		checkIsBlock(forStat.body, assert)
		assert.eq(#forStat.body.statements, 1)
		assert.eq(forStat.endKeyword.text, "end")

		block = parser.parseBlock("for j = 0, 5 do print(j) end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		forStat = block.statements[1] :: syntax.CstStatFor
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
		local block = parser.parseBlock("for key, value in arr do print(key, value) end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local forInStat = block.statements[1] :: syntax.CstStatForIn
		assert.eq(forInStat.tag, "forin")
		assert.eq(forInStat.forKeyword.text, "for")
		assert.eq(#forInStat.variables, 2)
		assert.eq(forInStat.variables[1].name.text, "key")
		assert.eq(forInStat.variables[2].name.text, "value")
		assert.eq(forInStat.inKeyword.text, "in")
		assert.eq(#forInStat.values, 1)
		assert.eq(forInStat.values[1].tag, "global")
		assert.eq(forInStat.doKeyword.text, "do")
		checkIsBlock(forInStat.body, assert)
		assert.eq(#forInStat.body.statements, 1)
		assert.eq(forInStat.endKeyword.text, "end")
	end)

	suite:case("parseStatAssign", function(assert)
		local block = parser.parseBlock("x = 1")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local assign = block.statements[1] :: syntax.CstStatAssign
		assert.eq(assign.tag, "assign")
		assert.eq(#assign.variables, 1)
		assert.eq(assign.variables[1].tag, "global")
		assert.eq(assign.equals.text, "=")
		assert.eq(#assign.values, 1)
		assert.eq(assign.values[1].tag, "number")
	end)

	suite:case("parseStatCompoundAssign", function(assert)
		local block = parser.parseBlock("x += 5")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local compound = block.statements[1] :: syntax.CstStatCompoundAssign
		assert.eq(compound.tag, "compoundassign")
		assert.eq(compound.variable.tag, "global")
		assert.eq(compound.operator.text, "+=")
		assert.eq(compound.value.tag, "number")
	end)

	suite:case("parseStatFunction", function(assert)
		local block = parser.parseBlock("@checked @native @deprecated function add(a, b) return a + b end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local funcStat = block.statements[1] :: syntax.CstStatFunction
		assert.eq(funcStat.tag, "function")
		assert.eq(#funcStat.func.attributes, 3)
		assert.eq((funcStat.func.attributes[1] :: syntax.CstAttribute).name.text, "@checked")
		assert.eq((funcStat.func.attributes[2] :: syntax.CstAttribute).name.text, "@native")
		assert.eq((funcStat.func.attributes[3] :: syntax.CstAttribute).name.text, "@deprecated")
		assert.eq(funcStat.func.functionKeyword.text, "function")
		assert.eq(funcStat.name.tag, "global")
		assert.eq((funcStat.name :: syntax.CstExprGlobal).name.text, "add")
		-- body parsing tested in parseExprFunction
	end)

	suite:case("parseStatLocalFunction", function(assert)
		local block = parser.parseBlock("local function multiply(x, y) return x * y end")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		local localFuncStat = block.statements[1] :: syntax.CstStatLocalFunction
		assert.eq(localFuncStat.tag, "localfunction")
		assert.eq(#localFuncStat.func.attributes, 0)
		assert.eq(localFuncStat.localKeyword.text, "local")
		assert.eq(localFuncStat.func.functionKeyword.text, "function")
		assert.eq(localFuncStat.name.name.text, "multiply")
	end)

	suite:case("parseStatTypeAlias", function(assert)
		local block = parser.parseBlock("type Vector3 = {x: number, y: number, z: number}")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.tag, "typealias")
		assert.eq(typeAlias.isExported, false)
		assert.eq(typeAlias.export, nil)
		assert.eq(typeAlias.typeToken.text, "type")
		assert.eq(typeAlias.name.text, "Vector3")
		assert.eq(typeAlias.openGenerics, nil)
		assert.eq(typeAlias.generics, nil)
		assert.eq(typeAlias.closeGenerics, nil)
		assert.eq(typeAlias.equals.text, "=")
		assert.eq(typeAlias.type.kind, "type")
		assert.eq(typeAlias.type.tag, "table")

		block = parser.parseBlock("export type Point<T, U...> = {x: T, y: T, f: (U...) -> ()}")
		checkIsBlock(block, assert)
		assert.eq(#block.statements, 1)

		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.neq(typeAlias.export, nil)
		assert.eq(typeAlias.isExported, true)
		assert.eq((typeAlias.export :: syntax.CstToken<"export">).text, "export")
		assert.neq(typeAlias.openGenerics, nil)
		assert.eq((typeAlias.openGenerics :: syntax.CstToken<"<">).text, "<")
		assert.neq(typeAlias.generics, nil)
		assert.eq(#typeAlias.generics :: syntax.CstPunctuated<syntax.CstGenericType>, 1)
		assert.neq(typeAlias.genericPacks, nil)
		assert.eq(#typeAlias.genericPacks :: syntax.CstPunctuated<syntax.CstGenericTypePack>, 1)
		assert.neq(typeAlias.closeGenerics, nil)
		assert.eq((typeAlias.closeGenerics :: syntax.CstToken<">">).text, ">")
	end)

	suite:case("parseStatTypeFunction", function(assert)
		local block = parser.parseBlock("type function foo() return types.number end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		local typeFunc = block.statements[1] :: syntax.CstStatTypeFunction
		assert.eq(typeFunc.tag, "typefunction")
		assert.eq(typeFunc.export, nil)
		assert.eq(typeFunc.type.text, "type")
		assert.eq(typeFunc.body.functionKeyword.text, "function")
		assert.eq(typeFunc.name.text, "foo")

		block = parser.parseBlock("export type function foo() return types.number end")
		assert.eq(block.tag, "block")
		assert.eq(#block.statements, 1)

		typeFunc = block.statements[1] :: syntax.CstStatTypeFunction
		assert.neq(typeFunc.export, nil)
		assert.eq((typeFunc.export :: syntax.CstToken<"export">).text, "export")
	end)
end)

test.suite("parse types", function(suite)
	-- CstGenericType and CstGenericTypePack are tested in parseExprFunction
	suite:case("testTypeReference", function(assert)
		local block = parser.parseBlock("type MyString = string")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "reference")

		local typeRef = typeAlias.type :: syntax.CstTypeReference
		assert.eq(typeRef.prefix, nil)
		assert.eq(typeRef.prefixPoint, nil)
		assert.eq(typeRef.name.text, "string")
		assert.eq(typeRef.openParameters, nil)
		assert.eq(typeRef.parameters, nil)
		assert.eq(typeRef.closeParameters, nil)

		block = parser.parseBlock("type MyTable = MyModule.Table<number, string>")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "reference")

		typeRef = typeAlias.type :: syntax.CstTypeReference
		assert.neq(typeRef.prefix, nil)
		assert.eq((typeRef.prefix :: syntax.CstToken<string>).text, "MyModule")
		assert.neq(typeRef.prefixPoint, nil)
		assert.eq((typeRef.prefixPoint :: syntax.CstToken<".">).text, ".")
		assert.eq(typeRef.name.text, "Table")
		assert.neq(typeRef.openParameters, nil)
		assert.eq((typeRef.openParameters :: syntax.CstToken<"<">).text, "<")
		assert.neq(typeRef.parameters, nil)
		assert.eq(#typeRef.parameters :: syntax.CstPunctuated<syntax.CstType>, 2)
		assert.eq((typeRef.parameters :: syntax.CstPunctuated<syntax.CstType>)[1].tag, "reference")
		assert.eq((typeRef.parameters :: syntax.CstPunctuated<syntax.CstType>)[2].tag, "reference")
		assert.neq(typeRef.closeParameters, nil)
		assert.eq((typeRef.closeParameters :: syntax.CstToken<">">).text, ">")
	end)

	suite:case("testTypeSingletonBoolean", function(assert)
		local block = parser.parseBlock("type TrueType = true")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "boolean")

		local singletonBool = typeAlias.type :: syntax.CstTypeSingletonBool
		assert.eq(singletonBool.token.text, "true")
		assert.that(singletonBool.value)

		block = parser.parseBlock("type FalseType = false")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "boolean")

		singletonBool = typeAlias.type :: syntax.CstTypeSingletonBool
		assert.eq(singletonBool.token.text, "false")
		assert.eq(singletonBool.value, false)
	end)

	suite:case("testTypeSingletonString", function(assert)
		local block = parser.parseBlock("type HelloType = 'hello'")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "string")

		local singletonStr = typeAlias.type :: syntax.CstTypeSingletonString
		assert.eq(singletonStr.value.text, "hello")
		assert.eq(singletonStr.quoteStyle, "single")

		block = parser.parseBlock('type WorldType = "world"')
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "string")

		singletonStr = typeAlias.type :: syntax.CstTypeSingletonString
		assert.eq(singletonStr.value.text, "world")
		assert.eq(singletonStr.quoteStyle, "double")
	end)

	suite:case("testTypeTypeof", function(assert)
		local block = parser.parseBlock("type T = typeof(someVariable)")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "typeof")

		local typeofType = typeAlias.type :: syntax.CstTypeTypeof
		assert.eq(typeofType.typeof.text, "typeof")
		assert.eq(typeofType.openParens.text, "(")
		assert.eq(typeofType.expression.tag, "global")
		assert.eq(typeofType.closeParens.text, ")")
	end)

	suite:case("testTypeGroup", function(assert)
		local block = parser.parseBlock("type T = (string)")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "group")

		local groupType = typeAlias.type :: syntax.CstTypeGroup
		assert.eq(groupType.openParens.text, "(")
		assert.eq(groupType.type.tag, "reference")
		assert.eq(groupType.closeParens.text, ")")
	end)

	suite:case("testTypeUnion", function(assert)
		local block = parser.parseBlock("type T = string | number | boolean")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "union")

		local unionType = typeAlias.type :: syntax.CstTypeUnion
		assert.eq(unionType.leading, nil)
		assert.eq(#unionType.types, 3)
		assert.eq(unionType.types[1].tag, "reference")
		assert.eq(unionType.types[2].tag, "reference")
		assert.eq(unionType.types[3].tag, "reference")

		block = parser.parseBlock("type T = | number?")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "union")

		unionType = typeAlias.type :: syntax.CstTypeUnion
		assert.neq(unionType.leading, nil)
		assert.eq((unionType.leading :: syntax.CstToken<"|">).text, "|")
		assert.eq(#unionType.types, 2)
		assert.eq(unionType.types[1].tag, "reference")
		assert.eq(unionType.types[2].tag, "optional")
		assert.eq((unionType.types[2] :: syntax.CstTypeOptional).token.text, "?")
	end)

	suite:case("testTypeUnionWithOptionalPart", function(assert)
		local block = parser.parseBlock("type T = number? | string")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "union")

		local unionType = typeAlias.type :: syntax.CstTypeUnion
		assert.eq(unionType.leading, nil)
		assert.eq(#unionType.types, 3)

		local node = unionType.types[1]
		assert.eq(node.tag, "reference")
		assert.eq(unionType.types.separators[1], nil)

		node = unionType.types[2]
		assert.eq(node.tag, "optional")
		assert.neq(unionType.types.separators[2], nil)
		assert.eq((unionType.types.separators[2] :: syntax.CstToken<"|">).text, "|")

		local node3 = unionType.types[3]
		assert.eq(node3.tag, "reference")
		assert.eq(unionType.types.separators[3], nil)
	end)

	suite:case("testTypeIntersection", function(assert)
		local block = parser.parseBlock("type T = A & B & C")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "intersection")

		local intersectionType = typeAlias.type :: syntax.CstTypeIntersection
		assert.eq(intersectionType.leading, nil)
		assert.eq(#intersectionType.types, 3)
		assert.eq(intersectionType.types[1].tag, "reference")
		assert.eq(intersectionType.types[2].tag, "reference")
		assert.eq(intersectionType.types[3].tag, "reference")

		block = parser.parseBlock("type T = & B")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "intersection")

		intersectionType = typeAlias.type :: syntax.CstTypeIntersection
		assert.neq(intersectionType.leading, nil)
		assert.eq((intersectionType.leading :: syntax.CstToken<"&">).text, "&")
		assert.eq(#intersectionType.types, 1)
		assert.eq(intersectionType.types[1].tag, "reference")
	end)

	suite:case("testTypeArray", function(assert)
		local block = parser.parseBlock("type T = { number }")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "array")

		local arrayType = typeAlias.type :: syntax.CstTypeArray
		assert.eq(arrayType.openBrace.text, "{")
		assert.eq(arrayType.access, nil)
		assert.eq(arrayType.type.tag, "reference")
		assert.eq(arrayType.closeBrace.text, "}")

		block = parser.parseBlock("type T = { read string }")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "array")

		arrayType = typeAlias.type :: syntax.CstTypeArray
		assert.neq(arrayType.access, nil)
		assert.eq((arrayType.access :: syntax.CstToken<"read" | "write">).text, "read")

		block = parser.parseBlock("type T = { write number }")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "array")

		arrayType = typeAlias.type :: syntax.CstTypeArray
		assert.neq(arrayType.access, nil)
		assert.eq((arrayType.access :: syntax.CstToken<"read" | "write">).text, "write")
	end)

	suite:case("parseTypeTable", function(assert)
		local block = parser.parseBlock("type T = {}")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")

		local tableType = typeAlias.type :: syntax.CstTypeTable
		assert.eq(tableType.openBrace.text, "{")
		assert.eq(#tableType.entries, 0)
		assert.eq(tableType.closeBrace.text, "}")

		block = parser.parseBlock("type T = {[number] : string}")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")

		tableType = typeAlias.type :: syntax.CstTypeTable
		assert.eq(#tableType.entries, 1)
		local tableTypeItem: any = tableType.entries[1]
		assert.eq(tableTypeItem.kind, "indexer")
		assert.eq(tableTypeItem.access, nil)
		assert.eq(tableTypeItem.indexerOpen.text, "[")
		assert.eq(tableTypeItem.key.tag, "reference")
		assert.eq(tableTypeItem.indexerClose.text, "]")
		assert.eq(tableTypeItem.colon.text, ":")
		assert.eq(tableTypeItem.value.tag, "reference")
		assert.eq(tableTypeItem.separator, nil)

		block = parser.parseBlock("type T = {['hello'] : 'world', read ['foo'] : number; write ['bar'] : boolean}")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")
		tableType = typeAlias.type :: syntax.CstTypeTable
		assert.eq(#tableType.entries, 3)
		tableTypeItem = tableType.entries[1]
		assert.eq(tableTypeItem.kind, "stringproperty")
		assert.eq(tableTypeItem.access, nil)
		assert.eq(tableTypeItem.indexerOpen.text, "[")
		assert.eq((tableTypeItem.key :: syntax.CstTypeSingletonString).kind, "type")
		assert.eq((tableTypeItem.key :: syntax.CstTypeSingletonString).tag, "string")
		assert.eq((tableTypeItem.key :: syntax.CstTypeSingletonString).value.text, "hello")
		assert.eq(tableTypeItem.indexerClose.text, "]")
		assert.eq(tableTypeItem.colon.text, ":")
		assert.eq(tableTypeItem.value.tag, "string")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.CstToken<"," | ";">).text, ",")

		tableTypeItem = tableType.entries[2]
		assert.eq(tableTypeItem.kind, "stringproperty")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.CstToken<"read" | "write">).text, "read")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.CstToken<"," | ";">).text, ";")

		tableTypeItem = tableType.entries[3]
		assert.eq(tableTypeItem.kind, "stringproperty")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.CstToken<"read" | "write">).text, "write")
		assert.eq(tableTypeItem.separator, nil)

		block = parser.parseBlock("type T = { hello: 'world'; read foo: number, write bar: boolean }")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "table")
		tableType = typeAlias.type :: syntax.CstTypeTable
		assert.eq(#tableType.entries, 3)
		tableTypeItem = tableType.entries[1]
		assert.eq(tableTypeItem.kind, "property")
		assert.eq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.key :: syntax.CstToken).text, "hello")
		assert.eq(tableTypeItem.colon.text, ":")
		assert.eq(tableTypeItem.value.tag, "string")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.CstToken<"," | ";">).text, ";")

		tableTypeItem = tableType.entries[2]
		assert.eq(tableTypeItem.kind, "property")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.CstToken<"read" | "write">).text, "read")
		assert.neq(tableTypeItem.separator, nil)
		assert.eq((tableTypeItem.separator :: syntax.CstToken<"," | ";">).text, ",")

		tableTypeItem = tableType.entries[3]
		assert.eq(tableTypeItem.kind, "property")
		assert.neq(tableTypeItem.access, nil)
		assert.eq((tableTypeItem.access :: syntax.CstToken<"read" | "write">).text, "write")
		assert.eq(tableTypeItem.separator, nil)
	end)

	suite:case("parseTypeFunction", function(assert)
		local block = parser.parseBlock("type T = (n : number, string) -> boolean")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "function")

		local funcType = typeAlias.type :: syntax.CstTypeFunction
		assert.eq(funcType.openGenerics, nil)
		assert.eq(funcType.generics, nil)
		assert.eq(funcType.genericPacks, nil)
		assert.eq(funcType.closeGenerics, nil)
		assert.eq(funcType.openParens.text, "(")
		assert.eq(#funcType.parameters, 2)

		local param = funcType.parameters[1]
		assert.neq(param.name, nil)
		assert.eq((param.name :: syntax.CstToken<string>).text, "n")
		assert.neq(param.colon, nil)
		assert.eq((param.colon :: syntax.CstToken<":">).text, ":")
		assert.eq(param.type.tag, "reference")

		param = funcType.parameters[2]
		assert.eq(param.name, nil)
		assert.eq(param.colon, nil)
		assert.eq(param.type.tag, "reference")

		assert.eq(funcType.vararg, nil)
		assert.eq(funcType.closeParens.text, ")")
		assert.eq(funcType.returnArrow.text, "->")
		assert.eq(funcType.returnTypes.kind, "typepack")

		block = parser.parseBlock("type T = <T, U...> (item: T, ...U) -> ()")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "function")

		funcType = typeAlias.type :: syntax.CstTypeFunction
		assert.neq(funcType.openGenerics, nil)
		assert.eq((funcType.openGenerics :: syntax.CstToken<"<">).text, "<")
		assert.neq(funcType.generics, nil)
		assert.eq(#funcType.generics :: syntax.CstPunctuated<syntax.CstGenericType>, 1)
		assert.neq(funcType.genericPacks, nil)
		assert.eq(#funcType.genericPacks :: syntax.CstPunctuated<syntax.CstGenericTypePack>, 1)
		assert.eq((funcType.genericPacks :: syntax.CstPunctuated<syntax.CstGenericTypePack>)[1].tag, "generic")

		local genericTypePack = (funcType.genericPacks :: syntax.CstPunctuated<syntax.CstGenericTypePack>)[1]
		assert.eq(genericTypePack.name.text, "U")
		assert.eq(genericTypePack.ellipsis.text, "...")

		assert.neq(funcType.closeGenerics, nil)
		assert.eq((funcType.closeGenerics :: syntax.CstToken<">">).text, ">")
		assert.neq(funcType.vararg, nil)
		assert.eq((funcType.vararg :: syntax.CstTypePack).kind, "typepack")

		block = parser.parseBlock("type T = () -> ...number")
		typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.type.tag, "function")

		funcType = typeAlias.type :: syntax.CstTypeFunction
		assert.eq(funcType.returnTypes.kind, "typepack")
		assert.eq(funcType.returnTypes.tag, "variadic")
		local variadicType: syntax.CstTypePackVariadic = funcType.returnTypes :: any
		assert.neq(variadicType.ellipsis, nil)
		assert.eq((variadicType.ellipsis :: syntax.CstToken<"...">).text, "...")
		assert.eq(variadicType.type.tag, "reference")
	end)
end)

test.suite("CST_nodes_frozen", function(suite)
	local frozenTableMessage = "attempt to modify a readonly table"

	-- Expression nodes
	suite:case("cstExprGroupFrozen", function(assert)
		local expr = parser.parseExpr("(x)")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "group")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
	end)

	suite:case("cstExprConstantNilFrozen", function(assert)
		local expr = parser.parseExpr("nil")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "nil")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("cstExprConstantBoolFrozen", function(assert)
		local expr = parser.parseExpr("true")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "boolean")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("cstExprConstantNumberFrozen", function(assert)
		local expr = parser.parseExpr("42")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "number")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("cstExprConstantIntegerFrozen", function(assert)
		local expr = parser.parseExpr("42i")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "integer")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).token.text = "blah"
		end)
	end)

	suite:case("cstExprConstantStringFrozen", function(assert)
		local expr = parser.parseExpr("'hello'")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "string")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).value.text = "blah"
		end)
	end)

	suite:case("cstExprLocalFrozen", function(assert)
		local block = parser.parseBlock("local x = 1\nreturn x")
		local returnStat = block.statements[2] :: syntax.CstStatReturn
		local expr = returnStat.expressions[1]
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "local")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).upvalue = true
		end)
	end)

	suite:case("cstExprGlobalFrozen", function(assert)
		local expr = parser.parseExpr("_G")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "global")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).name = nil
		end)
	end)

	suite:case("cstExprVarargsFrozen", function(assert)
		local expr = parser.parseExpr("...")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "vararg")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).tag = "modified"
		end)
	end)

	suite:case("cstExprCallFrozen", function(assert)
		local expr = parser.parseExpr("foo(1, 2)")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "call")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).func = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).arguments, nil :: any)
		end)
	end)

	suite:case("cstExprInstantiateFrozen", function(assert)
		local callExpr = parser.parseExpr("foo<<number, string>>()")
		assert.eq(callExpr.tag, "call")
		local expr = (callExpr :: syntax.CstExprCall).func
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "instantiate")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).expr = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).typeArguments, nil :: any)
		end)
	end)

	suite:case("cstExprIndexNameFrozen", function(assert)
		local expr = parser.parseExpr("obj.field")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "indexname")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).expression = nil
		end)
	end)

	suite:case("cstExprIndexExprFrozen", function(assert)
		local expr = parser.parseExpr("obj[key]")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "index")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).expression = nil
		end)
	end)

	suite:case("cstExprFunctionFrozen", function(assert)
		local expr = parser.parseExpr("@checked function<A, B...>(x, y) return x + y end")
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
			((expr :: syntax.CstExprFunction).attributes[1] :: any).name.text = "@modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).generics, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).genericPacks, nil :: any)
		end)
	end)

	suite:case("cstExprTableFrozen", function(assert)
		local expr = parser.parseExpr("{ a = 1, [2] = 3, 4 }")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "table")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).openBrace = nil
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

	suite:case("cstExprUnaryFrozen", function(assert)
		local expr = parser.parseExpr("-x")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "unary")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).operand = nil
		end)
	end)

	suite:case("cstExprBinaryFrozen", function(assert)
		local expr = parser.parseExpr("x + y")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "binary")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).lhsOperand = nil
		end)
	end)

	suite:case("cstExprInterpStringFrozen", function(assert)
		local expr = parser.parseExpr("`hello {x}`")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "interpolatedstring")
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).strings, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((expr :: any).expressions, nil :: any)
		end)
	end)

	suite:case("cstExprTypeAssertionFrozen", function(assert)
		local expr = parser.parseExpr("x :: number")
		assert.eq(expr.kind, "expr")
		assert.eq(expr.tag, "cast")
		assert.throwsWith(frozenTableMessage, function()
			(expr :: any).operand = nil
		end)
	end)

	suite:case("cstExprIfElseFrozen", function(assert)
		local expr = parser.parseExpr("if x then 1 elseif y then 2 else 3")
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
	suite:case("cstStatBlockFrozen", function(assert)
		local block = parser.parseBlock("local x = 1\nlocal y = 2")
		assert.eq(block.kind, "stat")
		assert.eq(block.tag, "block")
		assert.throwsWith(frozenTableMessage, function()
			table.insert((block :: any).statements, nil :: any)
		end)
		assert.throwsWith(frozenTableMessage, function()
			(block :: any).tag = nil
		end)
	end)

	suite:case("cstStatDoFrozen", function(assert)
		local block = parser.parseBlock("do local x = 1 end")
		local doStat = block.statements[1] :: syntax.CstStatDo
		assert.eq(doStat.kind, "stat")
		assert.eq(doStat.tag, "do")
		assert.throwsWith(frozenTableMessage, function()
			(doStat :: any).body = nil
		end)
	end)

	suite:case("cstStatIfFrozen", function(assert)
		local block = parser.parseBlock("if x then local y = 1 elseif z then local w = 2 else local v = 3 end")
		local ifStat = block.statements[1] :: syntax.CstStatIf
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

	suite:case("cstStatWhileFrozen", function(assert)
		local block = parser.parseBlock("while x do local y = 1 end")
		local whileStat = block.statements[1] :: syntax.CstStatWhile
		assert.eq(whileStat.kind, "stat")
		assert.eq(whileStat.tag, "while")
		assert.throwsWith(frozenTableMessage, function()
			(whileStat :: any).condition = nil
		end)
	end)

	suite:case("cstStatRepeatFrozen", function(assert)
		local block = parser.parseBlock("repeat local x = 1 until x > 10")
		local repeatStat = block.statements[1] :: syntax.CstStatRepeat
		assert.eq(repeatStat.kind, "stat")
		assert.eq(repeatStat.tag, "repeat")
		assert.throwsWith(frozenTableMessage, function()
			(repeatStat :: any).body = nil
		end)
	end)

	suite:case("cstStatBreakFrozen", function(assert)
		local block = parser.parseBlock("while true do break end")
		local whileStat = block.statements[1] :: syntax.CstStatWhile
		local breakStat = whileStat.body.statements[1] :: syntax.CstStatBreak
		assert.eq(breakStat.kind, "stat")
		assert.eq(breakStat.tag, "break")
		assert.throwsWith(frozenTableMessage, function()
			(breakStat :: any).tag = "modified"
		end)
	end)

	suite:case("cstStatContinueFrozen", function(assert)
		local block = parser.parseBlock("while true do continue end")
		local whileStat = block.statements[1] :: syntax.CstStatWhile
		local continueStat = whileStat.body.statements[1] :: syntax.CstStatContinue
		assert.eq(continueStat.kind, "stat")
		assert.eq(continueStat.tag, "continue")
		assert.throwsWith(frozenTableMessage, function()
			(continueStat :: any).tag = "modified"
		end)
	end)

	suite:case("cstStatReturnFrozen", function(assert)
		local block = parser.parseBlock("return 1, 2, 3")
		local returnStat = block.statements[1] :: syntax.CstStatReturn
		assert.eq(returnStat.kind, "stat")
		assert.eq(returnStat.tag, "return")
		assert.throwsWith(frozenTableMessage, function()
			(returnStat :: any).returnKeyword = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((returnStat :: any).expressions, nil)
		end)
	end)

	suite:case("cstStatExprFrozen", function(assert)
		local block = parser.parseBlock("foo()")
		local exprStat = block.statements[1] :: syntax.CstStatExpr
		assert.eq(exprStat.kind, "stat")
		assert.eq(exprStat.tag, "expression")
		assert.throwsWith(frozenTableMessage, function()
			(exprStat :: any).expression = nil
		end)
	end)

	suite:case("cstStatLocalFrozen", function(assert)
		local block = parser.parseBlock("local x, y = 1, 2")
		local localStat = block.statements[1] :: syntax.CstStatLocal
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

	suite:case("cstStatForFrozen", function(assert)
		local block = parser.parseBlock("for i = 1, 10, 2 do local x = i end")
		local forStat = block.statements[1] :: syntax.CstStatFor
		assert.eq(forStat.kind, "stat")
		assert.eq(forStat.tag, "for")
		assert.throwsWith(frozenTableMessage, function()
			(forStat :: any).variable = nil
		end)
	end)

	suite:case("cstStatForInFrozen", function(assert)
		local block = parser.parseBlock("for k, v in pairs(t) do local x = k end")
		local forInStat = block.statements[1] :: syntax.CstStatForIn
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

	suite:case("cstStatAssignFrozen", function(assert)
		local block = parser.parseBlock("x, y = 1, 2")
		local assignStat = block.statements[1] :: syntax.CstStatAssign
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

	suite:case("cstStatCompoundAssignFrozen", function(assert)
		local block = parser.parseBlock("x += 5")
		local compoundStat = block.statements[1] :: syntax.CstStatCompoundAssign
		assert.eq(compoundStat.kind, "stat")
		assert.eq(compoundStat.tag, "compoundassign")
		assert.throwsWith(frozenTableMessage, function()
			(compoundStat :: any).variable = nil
		end)
	end)

	suite:case("cstStatFunctionFrozen", function(assert)
		local block = parser.parseBlock("function foo() end")
		local funcStat = block.statements[1] :: syntax.CstStatFunction
		assert.eq(funcStat.kind, "stat")
		assert.eq(funcStat.tag, "function")
		assert.throwsWith(frozenTableMessage, function()
			(funcStat :: any).name = nil
		end)
	end)

	suite:case("cstStatLocalFunctionFrozen", function(assert)
		local block = parser.parseBlock("local function foo() end")
		local localFuncStat = block.statements[1] :: syntax.CstStatLocalFunction
		assert.eq(localFuncStat.kind, "stat")
		assert.eq(localFuncStat.tag, "localfunction")
		assert.throwsWith(frozenTableMessage, function()
			(localFuncStat :: any).name = nil
		end)
	end)

	suite:case("cstStatTypeAliasFrozen", function(assert)
		local block = parser.parseBlock("type Foo<T> = T")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		assert.eq(typeAlias.kind, "stat")
		assert.eq(typeAlias.tag, "typealias")
		assert.throwsWith(frozenTableMessage, function()
			(typeAlias :: any).name = nil
		end)
	end)

	suite:case("cstStatTypeFunctionFrozen", function(assert)
		local block = parser.parseBlock("type function foo() return function() end end")
		local typeFunc = block.statements[1] :: syntax.CstStatTypeFunction
		assert.eq(typeFunc.kind, "stat")
		assert.eq(typeFunc.tag, "typefunction")
		assert.throwsWith(frozenTableMessage, function()
			(typeFunc :: any).name = nil
		end)
	end)

	-- Type nodes
	suite:case("cstTypeReferenceFrozen", function(assert)
		local block = parser.parseBlock("type Foo = Bar<T>")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local typeRef = typeAlias.type :: syntax.CstTypeReference
		assert.eq(typeRef.kind, "type")
		assert.eq(typeRef.tag, "reference")
		assert.throwsWith(frozenTableMessage, function()
			(typeRef :: any).name = nil
		end)
	end)

	suite:case("cstTypeSingletonBoolFrozen", function(assert)
		local block = parser.parseBlock("type Foo = true")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local singletonBool = typeAlias.type :: syntax.CstTypeSingletonBool
		assert.eq(singletonBool.kind, "type")
		assert.eq(singletonBool.tag, "boolean")
		assert.throwsWith(frozenTableMessage, function()
			(singletonBool :: any).value = false
		end)
	end)

	suite:case("cstTypeSingletonStringFrozen", function(assert)
		local block = parser.parseBlock("type Foo = 'hello'")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local singletonStr = typeAlias.type :: syntax.CstTypeSingletonString
		assert.eq(singletonStr.kind, "type")
		assert.eq(singletonStr.tag, "string")
		assert.throwsWith(frozenTableMessage, function()
			(singletonStr :: any).quoteStyle = "double"
		end)
	end)

	suite:case("cstTypeTypeofFrozen", function(assert)
		local block = parser.parseBlock("type Foo = typeof(x)")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local typeofType = typeAlias.type :: syntax.CstTypeTypeof
		assert.eq(typeofType.kind, "type")
		assert.eq(typeofType.tag, "typeof")
		assert.throwsWith(frozenTableMessage, function()
			(typeofType :: any).expression = nil
		end)
	end)

	suite:case("cstTypeGroupFrozen", function(assert)
		local block = parser.parseBlock("type Foo = (Bar)")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local groupType = typeAlias.type :: syntax.CstTypeGroup
		assert.eq(groupType.kind, "type")
		assert.eq(groupType.tag, "group")
		assert.throwsWith(frozenTableMessage, function()
			(groupType :: any).type = nil
		end)
	end)

	suite:case("cstTypeOptionalFrozen", function(assert)
		local block = parser.parseBlock("type Foo = string?")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local unionType = typeAlias.type :: syntax.CstTypeUnion
		local optionalType = unionType.types[2] :: syntax.CstTypeOptional
		assert.eq(optionalType.kind, "type")
		assert.eq(optionalType.tag, "optional")
		assert.throwsWith(frozenTableMessage, function()
			(optionalType :: any).kind = "modified"
		end)
	end)

	suite:case("cstTypeUnionFrozen", function(assert)
		local block = parser.parseBlock("type Foo = string | number")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local unionType = typeAlias.type :: syntax.CstTypeUnion
		assert.eq(unionType.kind, "type")
		assert.eq(unionType.tag, "union")
		assert.throwsWith(frozenTableMessage, function()
			(unionType :: any).leading = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((unionType :: any).types, nil)
		end)
	end)

	suite:case("cstTypeIntersectionFrozen", function(assert)
		local block = parser.parseBlock("type Foo = A & B")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local intersectionType = typeAlias.type :: syntax.CstTypeIntersection
		assert.eq(intersectionType.kind, "type")
		assert.eq(intersectionType.tag, "intersection")
		assert.throwsWith(frozenTableMessage, function()
			(intersectionType :: any).leading = "modified"
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((intersectionType :: any).types, nil)
		end)
	end)

	suite:case("cstTypeArrayFrozen", function(assert)
		local block = parser.parseBlock("type Foo = {string}")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local arrayType = typeAlias.type :: syntax.CstTypeArray
		assert.eq(arrayType.kind, "type")
		assert.eq(arrayType.tag, "array")
		assert.throwsWith(frozenTableMessage, function()
			(arrayType :: any).type = nil
		end)
	end)

	suite:case("cstTypeTableFrozen", function(assert)
		local block = parser.parseBlock('type Foo = { a: number, [string]: boolean, ["hello"]: "world" }')
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local tableType = typeAlias.type :: syntax.CstTypeTable
		assert.eq(tableType.kind, "type")
		assert.eq(tableType.tag, "table")
		assert.throwsWith(frozenTableMessage, function()
			(tableType :: any).openBrace = nil
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

	suite:case("cstTypeFunctionFrozen", function(assert)
		local block = parser.parseBlock("type Foo = (x: number) -> string")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local funcType = typeAlias.type :: syntax.CstTypeFunction
		assert.eq(funcType.kind, "type")
		assert.eq(funcType.tag, "function")
		assert.throwsWith(frozenTableMessage, function()
			(funcType :: any).returnspecifier = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			(funcType :: any).parameters[1].name = nil
		end)
	end)

	suite:case("cstTypePackExplicitFrozen", function(assert)
		local block = parser.parseBlock("type Foo = (number, string) -> (boolean, string)")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local funcType = typeAlias.type :: syntax.CstTypeFunction
		local typePack = funcType.returnTypes :: syntax.CstTypePackExplicit
		assert.eq(typePack.kind, "typepack")
		assert.eq(typePack.tag, "explicit")
		assert.throwsWith(frozenTableMessage, function()
			(typePack :: any).openParens = nil
		end)
	end)

	suite:case("cstTypePackVariadicFrozen", function(assert)
		local block = parser.parseBlock("type Foo = () -> ...number")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local funcType = typeAlias.type :: syntax.CstTypeFunction
		local typePack = funcType.returnTypes :: syntax.CstTypePackVariadic
		assert.eq(typePack.kind, "typepack")
		assert.eq(typePack.tag, "variadic")
		assert.throwsWith(frozenTableMessage, function()
			(typePack :: any).type = nil
		end)
	end)

	-- Other node types
	suite:case("cstLocalFrozen", function(assert)
		local block = parser.parseBlock("local x: number = 1")
		local localStat = block.statements[1] :: syntax.CstStatLocal
		local local_ = localStat.variables[1]
		assert.eq(local_.kind, "local")
		assert.throwsWith(frozenTableMessage, function()
			(local_ :: any).name = nil
		end)
	end)

	suite:case("cstGenericTypeFrozen", function(assert)
		local block = parser.parseBlock("type Foo<T = number> = T")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local generic = (typeAlias.generics :: any)[1]
		assert.eq(generic.tag, "generic")
		assert.throwsWith(frozenTableMessage, function()
			generic.name = nil
		end)
	end)

	suite:case("cstGenericTypePackFrozen", function(assert)
		local block = parser.parseBlock("type Foo<T, U...> = (T, U...) -> ()")
		local typeAlias = block.statements[1] :: syntax.CstStatTypeAlias
		local genericPack = (typeAlias.genericPacks :: any)[1]
		assert.eq(genericPack.tag, "generic")
		assert.eq(genericPack.kind, "typepack")
		assert.throwsWith(frozenTableMessage, function()
			genericPack.name = nil
		end)
	end)

	-- Token type
	suite:case("tokenFrozen", function(assert)
		local block = parser.parseBlock("local x = 1")
		local localStat = block.statements[1] :: syntax.CstStatLocal
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
		local block = parser.parseBlock([=[
	-- This is a comment
	--[[This is a multiline comment
		hello
	]]

	local x = 1
	]=])
		local localStat = block.statements[1] :: syntax.CstStatLocal
		local trivias = localStat.localKeyword.leadingTrivia
		for _, trivia in trivias do
			assert.throwsWith(frozenTableMessage, function()
				(trivia :: any).text = "modified"
			end)
		end
	end)

	-- CstParseResult type
	suite:case("cstParseResultFrozen", function(assert)
		local result = parser.parse("local x = 1")
		assert.throwsWith(frozenTableMessage, function()
			(result :: any).root = nil
		end)
		assert.throwsWith(frozenTableMessage, function()
			table.insert((result :: any).lineOffsets, nil)
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

	suite:case("parseResultOnlyHasFourFields", function(assert)
		local result = parser.parse("local x = 1")
		local fieldCount = 0
		for _k, _v in result :: any do
			fieldCount = fieldCount + 1
		end
		assert.eq(fieldCount, 4)
	end)
end)
