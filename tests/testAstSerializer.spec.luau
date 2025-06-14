local luau = require("@lute/luau")
local fs = require("@lute/fs")

local parser = require("@batteries/syntax/parser")
local printer = require("@batteries/syntax/printer")
local T = require("@lute/luau")

local function assertEqualsLocation(
	actual: T.Location,
	startLine: number,
	startColumn: number,
	endLine: number,
	endColumn: number
)
	assert(actual.begin.line == startLine)
	assert(actual.begin.column == startColumn)
	assert(actual["end"].line == endLine)
	assert(actual["end"].column == endColumn)
end

local function test_tokenContainsLeadingSpaces()
	local block = luau.parse("  local x = 1").root
	assert(#block.statements == 1)

	local l = block.statements[1]
	assert(l.tag == "local")

	local token = l.localKeyword
	assert(#token.leadingTrivia == 1)
	assert(token.leadingTrivia[1].tag == "whitespace")
	assert(token.leadingTrivia[1].text == "  ")
	assertEqualsLocation(token.leadingTrivia[1].location, 0, 0, 0, 2)
end

local function test_tokenContainsLeadingNewline()
	local block = luau.parse("\n" .. "local x = 1").root
	assert(#block.statements == 1)

	local l = block.statements[1]
	assert(l.tag == "local")

	local token = l.localKeyword
	assert(#token.leadingTrivia == 1)
	assert(token.leadingTrivia[1].tag == "whitespace")
	assert(token.leadingTrivia[1].text == "\n")
	assertEqualsLocation(token.leadingTrivia[1].location, 0, 0, 1, 0)
end

local function test_tokenContainsLeadingSingleLineComment()
	local block = luau.parse("-- comment\n" .. "local x = 1").root
	assert(#block.statements == 1)

	local l = block.statements[1]
	assert(l.tag == "local")

	local token = l.localKeyword
	assert(#token.leadingTrivia == 2)
	assert(token.leadingTrivia[1].tag == "comment")
	assert(token.leadingTrivia[1].text == "-- comment")
	assertEqualsLocation(token.leadingTrivia[1].location, 0, 0, 0, 10)
	assert(token.leadingTrivia[2].tag == "whitespace")
	assert(token.leadingTrivia[2].text == "\n")
	assertEqualsLocation(token.leadingTrivia[2].location, 0, 10, 1, 0)
end

local function test_tokenContainsLeadingBlockComment()
	local block = luau.parse("--[[ comment ]] local x = 1").root
	assert(#block.statements == 1)

	local l = block.statements[1]
	assert(l.tag == "local")

	local token = l.localKeyword
	assert(#token.leadingTrivia == 2)
	assert(token.leadingTrivia[1].tag == "blockcomment")
	assert(token.leadingTrivia[1].text == "--[[ comment ]]")
	assertEqualsLocation(token.leadingTrivia[1].location, 0, 0, 0, 15)
	assert(token.leadingTrivia[2].tag == "whitespace")
	assert(token.leadingTrivia[2].text == " ")
	assertEqualsLocation(token.leadingTrivia[2].location, 0, 15, 0, 16)
end

local function test_tokenizeWhitespace()
	local block = luau.parse("  \n\t\t\n\n" .. "local x = 1").root
	assert(#block.statements == 1)

	local l = block.statements[1]
	assert(l.tag == "local")

	local token = l.localKeyword
	assert(#token.leadingTrivia == 3)
	assert(token.leadingTrivia[1].text == "  \n")
	assert(token.leadingTrivia[2].text == "\t\t\n")
	assert(token.leadingTrivia[3].text == "\n")
end

local function test_triviaSplitBetweenLeadingAndTrailing()
	local block = luau.parse("local x = 'test' -- comment\n" .. "-- comment 2\nlocal y = 'value'").root
	assert(#block.statements == 2)

	local firstStmt = block.statements[1]
	assert(firstStmt.tag == "local")

	local trailingToken = firstStmt.values[1].node
	assert(trailingToken.tag == "string")
	assert(#trailingToken.trailingTrivia == 3)
	assert(trailingToken.trailingTrivia[1].text == " ")
	assert(trailingToken.trailingTrivia[2].text == "-- comment")
	assert(trailingToken.trailingTrivia[3].text == "\n")

	local secondStmt = block.statements[2]
	assert(secondStmt.tag == "local")

	local leadingToken = secondStmt.localKeyword
	assert(#leadingToken.leadingTrivia == 2)
	assert(leadingToken.leadingTrivia[1].text == "-- comment 2")
	assert(leadingToken.leadingTrivia[2].text == "\n")
end

local function test_roundtrippableAst()
	local function visitDirectory(directory: string)
		for _, entry in fs.listdir(directory) do
			local path = `{directory}/{entry.name}`
			print(path)
			local source = fs.readfiletostring(path)
			local result = printer.printfile(parser.parsefile(source))

			print(result)
			assert(source == result)
		end
	end

	visitDirectory("examples")
	visitDirectory("tests/astSerializerTests")
end

local function test_lineOffsetsField()
	local singleLineCode = "local x = 1"
	local result = luau.parse(singleLineCode)

	assert(result.lineOffsets)
	assert(type(result.lineOffsets) == "table", "lineOffsets should be a table")
	assert(#result.lineOffsets == 1, "Should have 1 line offset for single line code") -- only line 0
	assert(result.lineOffsets[1] == 0, "First line should start at offset 0")

	local multiLineCode = "local x = 1\nlocal y = 2\nlocal z = 3"
	local multiResult = luau.parse(multiLineCode)

	assert(multiResult.lineOffsets)
	assert(type(multiResult.lineOffsets) == "table", "lineOffsets should be a table for multiline")
	assert(#multiResult.lineOffsets == 3, "Should have 3 line offsets for 3-line code") -- lines 0, 1, 2
	assert(multiResult.lineOffsets[1] == 0, "First line should start at offset 0")
	assert(multiResult.lineOffsets[2] == 12, "Second line should start after 'local x = 1\\n'")
	assert(multiResult.lineOffsets[3] == 24, "Third line should start after 'local x = 1\\nlocal y = 2\\n'")

	local emptyLineCode = "local x = 1\n\nlocal y = 2"
	local emptyResult = luau.parse(emptyLineCode)

	assert(emptyResult.lineOffsets)
	assert(#emptyResult.lineOffsets == 3, "Should have 3 line offsets including empty line")
	assert(emptyResult.lineOffsets[1] == 0, "First line should start at offset 0")
	assert(emptyResult.lineOffsets[2] == 12, "Second line (empty) should start after 'local x = 1\\n'")
	assert(emptyResult.lineOffsets[3] == 13, "Third line should start after empty line")
end

test_tokenContainsLeadingSpaces()
test_tokenContainsLeadingNewline()
test_tokenContainsLeadingSingleLineComment()
test_tokenContainsLeadingBlockComment()
test_tokenizeWhitespace()
test_triviaSplitBetweenLeadingAndTrailing()
test_roundtrippableAst()
test_lineOffsetsField()
