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
