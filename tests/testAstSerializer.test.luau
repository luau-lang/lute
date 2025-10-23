local asserts = require("@std/assert")
local fs = require("@std/fs")
local luau = require("@lute/luau")
local path = require("@std/path")
local test = require("@std/test")

local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local T = require("@lute/luau")

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

test.suite("AstSerializer", function(suite)
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
		trailingToken = trailingToken :: luau.AstExprConstantString
		assert.eq(#trailingToken.trailingtrivia, 3)
		assert.eq(trailingToken.trailingtrivia[1].text, " ")
		assert.eq(trailingToken.trailingtrivia[2].text, "-- comment")
		assert.eq(trailingToken.trailingtrivia[3].text, "\n")

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
		visitDirectory("tests/astSerializerTests")
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
end)

test.run()
