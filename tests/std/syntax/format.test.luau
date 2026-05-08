local fs = require("@std/fs")
local formatter = require("@std/syntax/format")
local path = require("@std/path")
local test = require("@std/test")

type Fixture = {
	sourcePath: string,
	snapshotPath: string,
}

local function checkFormat(assert: any, source: string, expected: string)
	local formatted = formatter.formatCode(source)
	assert.eq(formatted, expected)
	assert.eq(formatter.formatCode(formatted), formatted)
end

local STYLUA_FIXTURE_ROOT = path.join("tests", "std", "syntax", "fixtures", "format", "stylua")

local function collectStyluaFixtures(): { Fixture }
	local fixtures = {}

	for _, group in { "inputs", "inputs-luau", "inputs-luau-full_moon" } do
		local groupPath = path.join(STYLUA_FIXTURE_ROOT, group)
		for _, entry in fs.listDirectory(groupPath) do
			if entry.type == "file" and entry.name:match("%.lua$") then
				table.insert(fixtures, {
					sourcePath = path.format(path.join(groupPath, entry.name)),
					snapshotPath = path.format(path.join(STYLUA_FIXTURE_ROOT, "snapshots-lute", group, entry.name .. ".snap")),
				})
			end
		end
	end

	table.sort(fixtures, function(a: Fixture, b: Fixture)
		return a.sourcePath < b.sourcePath
	end)
	return fixtures
end

test.suite("SyntaxFormat", function(suite)
	suite:case("formatsLocalDeclaration", function(assert)
		checkFormat(assert, "local x=1", "local x = 1\n")
	end)

	suite:case("formatsBlockStatement", function(assert)
		checkFormat(assert, "if x then print(x) end", "if x then\n\tprint(x)\nend\n")
	end)

	suite:case("respectsExistingTableNewlines", function(assert)
		checkFormat(
			assert,
			"local value={\nfoo=1,\nbar=2,\n}",
			"local value = {\n\tfoo = 1,\n\tbar = 2,\n}\n"
		)
	end)

	suite:case("formatsFunctionBody", function(assert)
		checkFormat(
			assert,
			"local function identity(value)return value end",
			"local function identity(value)\n\treturn value\nend\n"
		)
	end)

	suite:case("preservesComments", function(assert)
		checkFormat(assert, "-- comment\nlocal x=1", "-- comment\nlocal x = 1\n")
	end)

	suite:case("formatsMultilineFunctionBody", function(assert)
		checkFormat(
			assert,
			"local function apply(\nvalue: string\n)local result=value\nreturn result\nend",
			"local function apply(\n\tvalue: string\n)\n\tlocal result = value\n\treturn result\nend\n"
		)
	end)

	suite:case("keepsInlineCommentAfterBlockStart", function(assert)
		checkFormat(
			assert,
			"if value then -- inline\nreturn value\nend",
			"if value then -- inline\n\treturn value\nend\n"
		)
	end)

	suite:case("keepsInlineCommentAfterFunctionSignature", function(assert)
		checkFormat(
			assert,
			"local function value(): number -- inline\nreturn 1\nend",
			"local function value(): number -- inline\n\treturn 1\nend\n"
		)
	end)

	suite:case("formatsSplitCommentAfterFunctionSignature", function(assert)
		checkFormat(
			assert,
			"local function value(): number\n-- body comment\nreturn 1\nend",
			"local function value(): number\n\t-- body comment\n\treturn 1\nend\n"
		)
	end)

	suite:case("restoresIndentAfterNestedFunctions", function(assert)
		checkFormat(
			assert,
			"local function outer(): { string }\nlocal inner=function() end\nreturn {}\nend\nlocal x=1",
			"local function outer(): { string }\n\tlocal inner = function() end\n\treturn {}\nend\nlocal x = 1\n"
		)
	end)

	suite:case("formatsChainAfterInlineComment", function(assert)
		checkFormat(
			assert,
			"return query\n.findAllFromRoot(ast, pred) -- inline\n:replace(function()\nreturn nil\nend)",
			"return query\n\t.findAllFromRoot(ast, pred) -- inline\n\t:replace(function()\n\t\treturn nil\n\tend)\n"
		)
	end)

	suite:case("formatsTypeFunctionGenericSpacing", function(assert)
		checkFormat(assert, "type A =<T>() -> ()", "type A = <T>() -> ()\n")
	end)

	suite:case("formatsTypeUnionContinuationAfterComments", function(assert)
		checkFormat(
			assert,
			"type Kind =\n\t| \"root\" -- root\n\t| \"defined\" -- defined",
			"type Kind =\n\t| \"root\" -- root\n\t| \"defined\" -- defined\n"
		)
	end)

	suite:case("formatsUnaryMinusInIfExpression", function(assert)
		checkFormat(
			assert,
			'return if sign == "-" then -math.huge else math.huge',
			'return if sign == "-" then -math.huge else math.huge\n'
		)
	end)

	suite:case("formatsMultilineIfExpression", function(assert)
		checkFormat(
			assert,
			"local value = if condition\nthen foo\nelse bar",
			"local value = if condition\n\tthen foo\n\telse bar\n"
		)
	end)

	for _, fixture in collectStyluaFixtures() do
		suite:case(`formatsStyLuaFixture_{fixture.sourcePath}`, function(assert)
			local source = fs.readFileToString(fixture.sourcePath)
			local formatted = formatter.formatCode(source)
			local expected = fs.readFileToString(fixture.snapshotPath)

			assert.eq(formatted, expected)
			assert.eq(formatter.formatCode(formatted), formatted)
		end)
	end
end)
