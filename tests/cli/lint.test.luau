local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local tableext = require("@std/tableext")
local test = require("@std/test")
local testTypes = require("@std/test/types")

local lutePath = path.format(process.execpath())
local tmpDir = system.tmpdir()
local rulesDir = path.format(path.join(".", "lints"))
local defaultRulesFolder = path.format(path.join("lute", "cli", "commands", "lint", "rules"))
local defaultRulesPaths = {
	almost_swapped = path.format(path.join(defaultRulesFolder, "almost_swapped.luau")),
	constant_table_comparison = path.format(path.join(defaultRulesFolder, "constant_table_comparison.luau")),
	divide_by_zero = path.format(path.join(defaultRulesFolder, "divide_by_zero.luau")),
	duplicate_keys = path.format(path.join(defaultRulesFolder, "duplicate_keys.luau")),
	parenthesized_conditions = path.format(path.join(defaultRulesFolder, "parenthesized_conditions.luau")),
	unused_variable = path.format(path.join(defaultRulesFolder, "unused_variable.luau")),
}

local LINT_RULE_MESSAGES = {
	almost_swapped = "warning[almost_swapped]: This looks like a failed attempt to swap.",
	constant_table_comparison = "warning[constant_table_comparison]: Constant table comparison detected. Comparing a table reference to a table literal will always evaluate to false.",
	divide_by_zero = "warning[divide_by_zero]: Division by zero detected.",
	duplicate_keys = "warning[duplicate_keys]: Duplicate keys detected in table literal.",
	parenthesized_conditions = "info[parenthesized_conditions]: Luau doesn't require parentheses around conditions. You can remove them for readability.",
	unused_variable = "warning[unused_variable]: Unused variable detected. Prefix this variable with '_' to indicate that it's intentionally unused.",
}

local USAGE = "Usage: lute lint [OPTIONS] [...PATHS]"

type lintTestParams = {
	content: string,
	expectedExitCode: number,
	rulePath: string?,
	expectedAutofixContents: string?,
	extraOptions: { string }?,
	outputExpectations: { { expectedOutput: string, count: number } }?,
}

local function lintTestHelper(assert: testTypes.asserts, params: lintTestParams): string
	-- Setup
	-- Create a file that violates the rule
	local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
	fs.writestringtofile(violatorPath, params.content)

	-- Do
	-- Run the transformer on the transformee
	local lintArgs = { lutePath, "lint" }

	if params.rulePath then
		table.insert(lintArgs, "-r")
		table.insert(lintArgs, params.rulePath)
	end

	if params.expectedAutofixContents then
		table.insert(lintArgs, "--auto-fix")
	end

	if params.extraOptions then
		tableext.extend(lintArgs, params.extraOptions)
	end

	table.insert(lintArgs, violatorPath)

	local result = process.run(lintArgs)

	-- Check
	assert.eq(result.exitcode, params.expectedExitCode)

	if params.expectedAutofixContents then
		local fixedContents = fs.readfiletostring(violatorPath)
		assert.eq(fixedContents, params.expectedAutofixContents)
	end

	if params.outputExpectations then
		for _, expectation in params.outputExpectations do
			if expectation.count == 0 then
				assert.strnotcontains(result.stdout, expectation.expectedOutput)
			else
				assert.strcontains(result.stdout, expectation.expectedOutput, nil, expectation.count)
			end
		end
	end

	-- Teardown
	fs.remove(violatorPath)

	return result.stdout
end

test.suite("lute lint", function(suite)
	suite:beforeeach(function()
		-- A test that creates rulesDir which fails won't cleanup after itself
		if fs.exists(rulesDir) then
			fs.removedirectory(rulesDir, { recursive = true })
		end

		local modulePath = path.join(tmpDir, "module")
		if fs.exists(modulePath) then
			fs.removedirectory(modulePath, { recursive = true })
		end
	end)

	suite:case("lute lint help message", function(assert)
		local result = process.run({ lutePath, "lint", "-h" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, USAGE)

		result = process.run({ lutePath, "lint", "--h" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, USAGE)

		result = process.run({ lutePath, "lint", "--help" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, USAGE)
	end)

	suite:case("lute lint no input file", function(assert)
		local result = process.run({ lutePath, "lint", "-r", "a_rule.luau" })

		assert.eq(result.exitcode, 1)
		assert.strcontains(result.stdout, "Error: No input files or string input specified.")
	end)

	suite:case("lute lint error code 0 with no violations", function(assert)
		local output = lintTestHelper(assert, { content = "", expectedExitCode = 0 })

		assert.eq(output, "")
	end)

	suite:case("lute lint verbose", function(assert)
		local output = lintTestHelper(assert, {
			content = "",
			expectedExitCode = 0,
			extraOptions = { "-v" },
			outputExpectations = {
				{ expectedOutput = "Using default lint rules.", count = 1 },
				{ expectedOutput = "Applying lint rules", count = 1 },
				{ expectedOutput = "Printing violations from 0 files", count = 1 },
			},
		})

		assert.neq(output:find("Reading input file '.+violator%.luau'"), nil)
		assert.neq(output:find("Parsing input file '.+violator%.luau'"), nil)
	end)

	suite:case("divide_by_zero", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 1 / 0
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("divide_by_zero auto-fix", function(assert)
		lintTestHelper(assert, {
			content = [[
local _x = 1 / 0
local _y = -3 // 0
local _z = 4 % 0
local _nan = 0 / 0
local _negnan = -0 / 0
]],
			expectedExitCode = 0,
			expectedAutofixContents = [[
local _x = math.huge
local _y = -math.huge
local _z = 0 / 0
local _nan = 0 / 0
local _negnan = 0 / 0
]],
		})
	end)

	suite:case("almost_swapped", function(assert)
		lintTestHelper(assert, {
			content = [[
a = b
b = a

local x = 0
local y = "hello"
x = y
y = x

local t = { a = 1, b = 2 }
t.a = t.b
t.b = t.a

if true then
	t["a"] = t["b"]
	t["b"] = t["a"]
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.almost_swapped,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 4 },
				{
					expectedOutput = [[
violator.luau:1:1-2:6 ──
   │
 1 │ ╭ a = b
 2 │ │ b = a
   │ ╰─────^
   │

Suggested fix: a, b = b, a
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:6:1-7:6 ──
   │
 6 │ ╭ x = y
 7 │ │ y = x
   │ ╰─────^
   │

Suggested fix: x, y = y, x
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:10:1-11:10 ──
    │
 10 │ ╭ t.a = t.b
 11 │ │ t.b = t.a
    │ ╰─────────^
    │

Suggested fix: t.a, t.b = t.b, t.a
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:14:2-15:17 ──
    │
 14 │ ╭     t["a"] = t["b"]
 15 │ │     t["b"] = t["a"]
    │ ╰───────────────────^
    │

Suggested fix: t["a"], t["b"] = t["b"], t["a"]
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("almost swapped auto-fix", function(assert)
		lintTestHelper(assert, {
			content = [[
a = b
b = a

local x = 0
local y = "hello"
x = y
y = x

local t = { a = 1, b = 2 }
t.a = t.b
t.b = t.a

if true then
	t["a"] = t["b"]
	t["b"] = t["a"]
end
]],
			expectedExitCode = 0,
			expectedAutofixContents = [[
a, b = b, a

local x = 0
local y = "hello"
x, y = y, x

local t = { a = 1, b = 2 }
t.a, t.b = t.b, t.a

if true then
	t["a"], t["b"] = t["b"], t["a"]
end
]],
		})
	end)

	suite:case("lute lint custom rules dir", function(assert)
		-- TODO: Use new helper after adding option to turn off default rules
		-- Setup
		fs.createdirectory(rulesDir)
		-- Copy almostSwapped.luau to rulesDir/almostSwapped.luau
		-- Because the default rules require types using a relative path, we copy from examples, which uses an absolute require path
		fs.copy(path.join("examples", "lints", "almost_swapped.luau"), path.join(rulesDir, "almost_swapped.luau"))
		-- Copy divide_by_zero to rulesDir/divide_by_zero/init.luau
		local divideByZeroDir = path.join(rulesDir, "divide_by_zero")
		fs.createdirectory(divideByZeroDir)
		fs.copy(path.join("examples", "lints", "divide_by_zero.luau"), path.join(divideByZeroDir, "init.luau"))
		fs.writestringtofile(
			path.join(rulesDir, "bogus.txt"),
			[[
not a luau file
]]
		)

		-- Create a file that violates the rule
		local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
		fs.writestringtofile(
			violatorPath,
			[[
local x = 1 / 0

a = b
b = a
    ]]
		)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "lint", "-r", rulesDir, violatorPath })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
		local expected = [[
violator.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]]
		assert.strcontains(result.stdout, expected)

		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.almost_swapped)
		expected = [[
violator.luau:3:1-4:6 ──
   │
 3 │ ╭ a = b
 4 │ │ b = a
   │ ╰─────^
   │
]]
		assert.strcontains(result.stdout, expected)

		-- Teardown
		fs.remove(violatorPath)
		fs.removedirectory(rulesDir, { recursive = true })
	end)

	suite:case("lute lint multiple rules but one errors", function(assert)
		-- TODO: Use new helper after adding option to turn off default rules
		-- Setup
		fs.createdirectory(rulesDir)
		-- Copy almostSwapped.luau to rulesDir/almostSwapped.luau
		fs.copy(path.join("examples", "lints", "almost_swapped.luau"), path.join(rulesDir, "almost_swapped.luau"))
		-- Create a rule that fails
		fs.writestringtofile(
			path.join(rulesDir, "erroring_rule.luau"),
			[[
return table.freeze({
	name = "AlwaysErrors",
	lint = function(ast, sourcepath)
		error("This rule always errors")
	end,
})
]]
		)

		-- Create a file that violates the rule
		local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
		fs.writestringtofile(
			violatorPath,
			[[
a = b
b = a
    ]]
		)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "lint", "-r", rulesDir, violatorPath })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.almost_swapped)
		local expected = [[
violator.luau:1:1-2:6 ──
   │
 1 │ ╭ a = b
 2 │ │ b = a
   │ ╰─────^
   │
]]
		assert.strcontains(result.stdout, expected)

		assert.neq(
			result.stdout:find(
				"Error applying lint rule 'AlwaysErrors': %.[/\\]lints[/\\]erroring_rule%.luau:4: This rule always errors",
				1
			),
			nil
		)

		-- Teardown
		fs.remove(violatorPath)
		fs.removedirectory(rulesDir, { recursive = true })
	end)

	suite:case("lute lint multiple input files", function(assert)
		-- Setup
		-- Create multiple files that violate the rule
		local violatorPath1 = path.format(path.join(tmpDir, "violator1.luau"))
		fs.writestringtofile(
			violatorPath1,
			[[
local x = 1 / 0

a = b
b = a
    ]]
		)

		local modulePath = path.join(tmpDir, "module")
		fs.createdirectory(modulePath)
		local violatorPath2 = path.format(path.join(modulePath, "violator2.lua"))
		fs.writestringtofile(
			violatorPath2,
			[[
local y = 10 / 0

local x = 0
local y = "hello"
x = y
y = x
    ]]
		)
		fs.writestringtofile(path.format(path.join(modulePath, "not_luau.txt")), "blablabla")

		-- Do
		-- Run the transformer on the transformee
		local result =
			process.run({ lutePath, "lint", "-r", "examples/lints", "-v", violatorPath1, path.format(modulePath) })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.eq(#result.stdout:split(LINT_RULE_MESSAGES.divide_by_zero), 3)
		local expected = [[
violator1.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]]
		assert.strcontains(result.stdout, expected)

		expected = [[
violator2.lua:1:11-17 ──
   │
 1 │ local y = 10 / 0
   │           ^^^^^^
   │
]]
		assert.strcontains(result.stdout, expected)

		assert.eq(#result.stdout:split(LINT_RULE_MESSAGES.almost_swapped), 3)
		expected = [[
violator1.luau:3:1-4:6 ──
   │
 3 │ ╭ a = b
 4 │ │ b = a
   │ ╰─────^
   │
]]
		assert.strcontains(result.stdout, expected)

		expected = [[
violator2.lua:5:1-6:6 ──
   │
 5 │ ╭ x = y
 6 │ │ y = x
   │ ╰─────^
   │
]]
		assert.strcontains(result.stdout, expected)
		expected = "Skipping non%-Luau file '.+[/\\]module[/\\]not_luau%.txt'"
		assert.neq(result.stdout:find(expected, 1, false), nil)

		-- Teardown
		fs.remove(violatorPath1)
		fs.removedirectory(modulePath, { recursive = true })
	end)

	suite:case("lute lint multiple files with errors recovers", function(assert)
		-- Setup
		-- Create multiple files that violate the rule
		local lintee = path.format(path.join(tmpDir, "lintee.luau"))
		fs.writestringtofile(lintee, "bogus")

		local violatorPath = path.format(path.join(tmpDir, "violator1.luau"))
		fs.writestringtofile(
			violatorPath,
			[[
local x = 1 / 0

a = b
b = a
    ]]
		)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "lint", "-r", "examples/lints", lintee, violatorPath })

		-- Check
		assert.eq(result.exitcode, 1)

		local expected = [[
lintee.luau': @std/syntax/parser.luau:12: parsing failed:
(0, 0) - (0, 5): Incomplete statement: expected assignment or a function call
]]
		assert.strcontains(result.stdout, expected)

		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.almost_swapped)

		-- Teardown
		fs.remove(lintee)
		fs.remove(violatorPath)
	end)

	suite:case("lute lint default rules", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 1 / 0

a = b
b = a
]],
			expectedExitCode = 1,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]],
					count = 1,
				},
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 1 },
				{
					expectedOutput = [[
violator.luau:3:1-4:6 ──
   │
 3 │ ╭ a = b
 4 │ │ b = a
   │ ╰─────^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("lute lint warning suppression", function(assert)
		lintTestHelper(assert, {
			content = [[
-- lute-lint-ignore(divide_by_zero)
local x = 1 / 0

-- lute-lint-ignore(divide_by_zero)
if true then
	local y = 10 / 0
end

a = b
b = a
]],
			expectedExitCode = 1,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 0 },
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 1 },
				{
					expectedOutput = [[
violator.luau:9:1-10:6 ──
    │
 9  │ ╭ a = b
 10 │ │ b = a
    │ ╰─────^
    │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("suppression is limited to following statement", function(assert)
		lintTestHelper(assert, {
			content = [[
-- lute-lint-ignore(divide_by_zero)
local x = 1 / 0

-- lute-lint-ignore(divide_by_zero)
if true then
	local y = 10 / 0
end

a = b
b = a
]],
			expectedExitCode = 1,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 0 },
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 1 },
				{
					expectedOutput = [[
violator.luau:9:1-10:6 ──
    │
 9  │ ╭ a = b
 10 │ │ b = a
    │ ╰─────^
    │
]],
					count = 1,
				},
			},
		})

		-- Setup
		-- Create a file that violates the rule
		local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
		fs.writestringtofile(
			violatorPath,
			[[
-- lute-lint-ignore(divide_by_zero)
local x = 1 / 0

if true then
	local y = 10 / 0
end

local z = 1 / 0
    ]]
		)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "lint", "-r", defaultRulesPaths.divide_by_zero, violatorPath })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero, nil, 2)
		local expected = [[
violator.luau:5:12-18 ──
   │
 5 │     local y = 10 / 0
   │               ^^^^^^
   │
]]
		assert.strcontains(result.stdout, expected)

		expected = [[
violator.luau:8:11-16 ──
   │
 8 │ local z = 1 / 0
   │           ^^^^^
   │
]]
		assert.strcontains(result.stdout, expected)

		-- Teardown
		fs.remove(violatorPath)
	end)

	suite:case("suppression is limited to following statement2", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 1 / 0

-- lute-lint-ignore(divide_by_zero)
if true then
	local y = 10 / 0
end

local z = 1 / 0
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 2 },
				{
					expectedOutput = [[
violator.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:8:11-16 ──
   │
 8 │ local z = 1 / 0
   │           ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("suppression is limited to following statement3", function(assert)
		lintTestHelper(assert, {
			content = [[
local function foo()
	-- lute-lint-ignore(divide_by_zero)
	local y = 3 / 0

	return 3 / 0
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
				{
					expectedOutput = [[
violator.luau:5:9-14 ──
   │
 5 │     return 3 / 0
   │            ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("suppression is limited to following statement4", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	-- lute-lint-ignore(divide_by_zero)
	local y = 3 / 0

	return 3 / 0
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
				{
					expectedOutput = [[
violator.luau:5:9-14 ──
   │
 5 │     return 3 / 0
   │            ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("suppression is limited to following statement5", function(assert)
		lintTestHelper(assert, {
			content = [[
while true do
	-- lute-lint-ignore(divide_by_zero)
	local y = 3 / 0

	return 3 / 0
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
				{
					expectedOutput = [[
violator.luau:5:9-14 ──
   │
 5 │     return 3 / 0
   │            ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("suppression is limited to following statement6", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = {}
for _, _ in t do
	-- lute-lint-ignore(divide_by_zero)
	local y = 3 / 0

	return 3 / 0
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
				{
					expectedOutput = [[
violator.luau:6:9-14 ──
   │
 6 │     return 3 / 0
   │            ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("suppression for multi node violation", function(assert)
		lintTestHelper(assert, {
			content = [[
-- lute-lint-ignore(almost_swapped)
a = b
b = a
    ]],
			expectedExitCode = 0,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 0 },
			},
		})
	end)

	suite:case("suppression for multi node violation", function(assert)
		lintTestHelper(assert, {
			content = [[
-- lute-lint-ignore(almost_swapped)
a = b
b = a
a = b
    ]],
			expectedExitCode = 1,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 1 },
				{
					expectedOutput = [[
violator.luau:3:1-4:6 ──
   │
 3 │ ╭ b = a
 4 │ │ a = b
   │ ╰─────^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("nested suppressions", function(assert)
		lintTestHelper(assert, {
			content = [[
-- lute-lint-ignore(divide_by_zero)
local function _foo()
    local _x = 1/0
    local function _bar()
        -- lute-lint-ignore(almost_swapped)
        a = b
		b = a
    end
end
    ]],
			expectedExitCode = 0,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 0 },
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 0 },
			},
		})
	end)

	suite:case("json output", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 1 / 0
    ]],
			expectedExitCode = 0,
			extraOptions = { "-j" },
			outputExpectations = {
				{
					expectedOutput = [[
{
    "items": [
        {
            "items": [
                {
                    "message": "Unused variable detected. Prefix this variable with '_' to indicate that it's intentionally unused.", 
                    "codeDescription": "https://lute.luau.org/cli/lint/unused_variable.html", 
                    "source": "lute lint", 
                    "code": "unused_variable", 
                    "severity": 2, 
                    "range": {
                        "start": {
                            "character": 6, 
                            "line": 0
                        }, 
                        "end": {
                            "character": 7, 
                            "line": 0
                        }
                    }
                },
                {
                    "message": "Division by zero detected.", 
                    "codeDescription": "https://lute.luau.org/cli/lint/divide_by_zero.html", 
                    "source": "lute lint", 
                    "code": "divide_by_zero", 
                    "severity": 2, 
                    "range": {
                        "start": {
                            "character": 10, 
                            "line": 0
                        }, 
                        "end": {
                            "character": 15, 
                            "line": 0
                        }
                    }, 
                    "suggestedfix": {
                        "range": {
                            "start": {
                                "character": 10, 
                                "line": 0
                            }, 
                            "end": {
                                "character": 15, 
                                "line": 0
                            }
                        }, 
                        "fix": "math.huge"
                    }
                }
            ], 
            "uri":]], -- URI has absolute tmpdir path, so we cut off here
					count = 1,
				},
			},
		})
	end)

	suite:case("lute lint respects gitignore", function(assert)
		-- Setup
		-- Create a module directory with a .gitignore that ignores one file
		local modulePath = path.join(tmpDir, "module")
		fs.createdirectory(modulePath)
		local violatorPath1 = path.format(path.join(modulePath, "violator1.luau"))
		fs.writestringtofile(
			violatorPath1,
			[[
local x = 10 / 0
    ]]
		)
		local violatorPath2 = path.format(path.join(modulePath, "violator2.luau"))
		fs.writestringtofile(
			violatorPath2,
			[[
local y = 10 / 0
    ]]
		)
		fs.writestringtofile(path.format(path.join(modulePath, ".gitignore")), "violator2.luau\n")

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "lint", path.format(modulePath) })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero, nil, 1)
		local expected = [[
violator1.luau:1:11-17 ──
   │
 1 │ local x = 10 / 0
   │           ^^^^^^
   │
]]
		assert.strcontains(result.stdout, expected)

		expected = [[
violator2.lua:1:11-17 ──
   │
 1 │ local y = 10 / 0
   │           ^^^^^^
   │
]]
		assert.strnotcontains(result.stdout, expected)

		-- Teardown
		fs.removedirectory(modulePath, { recursive = true })
	end)

	suite:case("lute lint report directive", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 1 / 0
-- lute-lint-ignore(divide_by_zero)
if true then
	local z = 3 / 0
	-- lute-lint-report(divide_by_zero)
	local y = 10 / 0
end
    ]],
			expectedExitCode = 1,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 2 },
				{
					expectedOutput = [[
violator.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:6:12-18 ──
   │
 6 │     local y = 10 / 0
   │               ^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("lute lint global ignore directive", function(assert)
		lintTestHelper(assert, {
			content = [[
-- lute-lint-global-ignore(divide_by_zero)
local x = 1 / 0
-- lute-lint-report(divide_by_zero)
if true then
	local z = 3 / 0
	-- lute-lint-ignore(divide_by_zero)
	local y = 10 / 0
end
    ]],
			expectedExitCode = 1,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
				{
					expectedOutput = [[
violator.luau:5:12-17 ──
   │
 5 │     local z = 3 / 0
   │               ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("lute lint string input", function(assert)
		local inputString = [[
a = b
b = a
]]

		-- Do
		-- Run the linter on string input
		local result = process.run({ lutePath, "lint", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.almost_swapped)
		local expected = [[
   ┌── input:1:1-2:6 ──
   │
 1 │ ╭ a = b
 2 │ │ b = a
   │ ╰─────^
   │
]]
		assert.strcontains(result.stdout, expected)
	end)

	suite:case("lute lint string input verbose", function(assert)
		local inputString = "local x = 1 / 0"

		-- Do
		-- Run the linter on string input with verbose flag
		local result = process.run({ lutePath, "lint", "-v", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strcontains(result.stdout, "Using default lint rules.")
		assert.strcontains(result.stdout, "Parsing input string")
		assert.strcontains(result.stdout, "Parsing global lint ignores in input string")
		assert.strcontains(result.stdout, "Applying lint rules")
		assert.strcontains(result.stdout, "Printing violations from string input")
		assert.strcontains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
	end)

	suite:case("lute lint string input with no violations", function(assert)
		local inputString = "x = 1 + 2"

		-- Do
		-- Run the linter on string input
		local result = process.run({ lutePath, "lint", "-v", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "No lint violations found.")
	end)

	suite:case("lute lint string input json output", function(assert)
		local inputString = "local x = 1 / 0"

		-- Do
		-- Run the linter on string input with json flag
		local result = process.run({ lutePath, "lint", "-j", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 0)

		local expected = [=[
[
    {
        "message": "Unused variable detected. Prefix this variable with '_' to indicate that it's intentionally unused.", 
        "codeDescription": "https://lute.luau.org/cli/lint/unused_variable.html", 
        "source": "lute lint", 
        "code": "unused_variable", 
        "severity": 2, 
        "range": {
            "start": {
                "character": 6, 
                "line": 0
            }, 
            "end": {
                "character": 7, 
                "line": 0
            }
        }
    },
    {
        "message": "Division by zero detected.", 
        "codeDescription": "https://lute.luau.org/cli/lint/divide_by_zero.html", 
        "source": "lute lint", 
        "code": "divide_by_zero", 
        "severity": 2, 
        "range": {
            "start": {
                "character": 10, 
                "line": 0
            }, 
            "end": {
                "character": 15, 
                "line": 0
            }
        }, 
        "suggestedfix": {
            "range": {
                "start": {
                    "character": 10, 
                    "line": 0
                }, 
                "end": {
                    "character": 15, 
                    "line": 0
                }
            }, 
            "fix": "math.huge"
        }
    }
]]=]
		assert.strcontains(result.stdout, expected)
	end)

	suite:case("lute lint ignore (table item)", function(assert)
		lintTestHelper(assert, {
			content = [[
local y = {
    -- lute-lint-ignore(divide_by_zero)
    x = 3 / 0
}

local z = 5 / 0
]],
			expectedExitCode = 1,
			outputExpectations = {
				{ expectedOutput = "Error linting file", count = 0 },
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 1 },
			},
		})
	end)

	suite:case("parenthesized_conditions", function(assert)
		lintTestHelper(assert, {
			content = [[
if (3 > 0) then
	print("Hello, world!")
elseif (false) then
	print("This won't print.")
end

local x = if (2 < 1) then 10 elseif (true) then 3 else 20

while ("hello" == "world") do
	print("Nope.")
end

repeat
	print("Still nope.")
until (5 == 5)
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.parenthesized_conditions,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.parenthesized_conditions,
					count = 6,
				},
				{
					expectedOutput = [[
violator.luau:1:4-11 ──
   │
 1 │ if (3 > 0) then
   │    ^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:3:8-15 ──
   │
 3 │ elseif (false) then
   │        ^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = "violator.luau:7:14-21 ──",
					count = 1,
				},
				{
					expectedOutput = [[
   │
 7 │ local x = if (2 < 1) then 10 elseif (true) then 3 else 20
   │              ^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = "violator.luau:7:37-43 ──",
					count = 1,
				},
				{
					expectedOutput = [[
   │
 7 │ local x = if (2 < 1) then 10 elseif (true) then 3 else 20
   │                                     ^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:9:7-27 ──
   │
 9 │ while ("hello" == "world") do
   │       ^^^^^^^^^^^^^^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:15:7-15 ──
    │
 15 │ until (5 == 5)
    │       ^^^^^^^^
    │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("parenthesized_conditions auto-fix", function(assert)
		lintTestHelper(assert, {
			content = [[
if (3 > 0) then
	print("Hello, world!")
elseif (false) then
	print("This won't print.")
end

local x = if (2 < 1) then 10 elseif (true) then 3 else 20

while ("hello" == "world") do
	print("Nope.")
end

repeat
	print("Still nope.")
until (5 == 5)
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.parenthesized_conditions,
			expectedAutofixContents = [[
if 3 > 0 then
	print("Hello, world!")
elseif false then
	print("This won't print.")
end

local x = if 2 < 1 then 10 elseif true then 3 else 20

while "hello" == "world" do
	print("Nope.")
end

repeat
	print("Still nope.")
until 5 == 5
]],
		})
	end)

	suite:case("report violations remaining after auto-fix", function(assert)
		lintTestHelper(assert, {
			content = [[
a = b
b = a

local x = t == { x = 3 }
]],
			expectedExitCode = 1,
			expectedAutofixContents = [[
a, b = b, a

local x = t == { x = 3 }
]],
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.constant_table_comparison,
					count = 1,
				},
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 0 },
			},
		})
	end)

	suite:case("constant_table_comparison", function(assert)
		lintTestHelper(assert, {
			content = [[
local a = { 1, 2, 3 } == t
local b = t == { 4, 5, 6 }
local c = { 1 } == t
local d = t == ({ 4 } :: { string })
local e = t ~= { 1, 2 }
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.constant_table_comparison,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.constant_table_comparison,
					count = 5,
				},
				{
					expectedOutput = [[
violator.luau:1:11-27 ──
   │
 1 │ local a = { 1, 2, 3 } == t
   │           ^^^^^^^^^^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:2:11-27 ──
   │
 2 │ local b = t == { 4, 5, 6 }
   │           ^^^^^^^^^^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:3:11-21 ──
   │
 3 │ local c = { 1 } == t
   │           ^^^^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:4:11-37 ──
   │
 4 │ local d = t == ({ 4 } :: { string })
   │           ^^^^^^^^^^^^^^^^^^^^^^^^^^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:5:11-24 ──
   │
 5 │ local e = t ~= { 1, 2 }
   │           ^^^^^^^^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("constant_table_comparison auto-fix", function(assert)
		lintTestHelper(assert, {
			content = [[
local a = {} == t
local b = t == {}
local c = t == ({})
local d = t == ({} :: { string })
local e = t ~= {}
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.constant_table_comparison,
			expectedAutofixContents = [[
local a = next(t) == nil
local b = next(t) == nil
local c = next(t) == nil
local d = next(t) == nil
local e = next(t) ~= nil
]],
		})
	end)

	suite:case("lute lint json output includes suggestedfix", function(assert)
		local inputString = [[
			a = b
			b = a
		]]

		-- Do
		-- Run the linter on string input with json flag
		local result = process.run({ lutePath, "lint", "-j", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 0)

		local expected = [=[
[
    {
        "message": "This looks like a failed attempt to swap.", 
        "codeDescription": "https://lute.luau.org/cli/lint/almost_swapped.html", 
        "source": "lute lint", 
        "code": "almost_swapped", 
        "severity": 2, 
        "range": {
            "start": {
                "character": 3, 
                "line": 0
            }, 
            "end": {
                "character": 8, 
                "line": 1
            }
        }, 
        "suggestedfix": {
            "range": {
                "start": {
                    "character": 3, 
                    "line": 0
                }, 
                "end": {
                    "character": 8, 
                    "line": 1
                }
            }, 
            "fix": "a, b = b, a"
        }
    }
]]=]
		assert.strcontains(result.stdout, expected)
	end)

	suite:case("unused_variable_1", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 3
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 3
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_2", function(assert)
		lintTestHelper(assert, {
			content = [[
local _ = 3
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unused_variable_3", function(assert)
		lintTestHelper(assert, {
			content = [[
for i = 3, 4 do
	print(3)
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:5-6 ──
   │
 1 │ for i = 3, 4 do
   │     ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_4", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = {1, 2, 3}
for i, v in t do
	print(3)
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 2,
				},
				{
					expectedOutput = [[
violator.luau:2:5-6 ──
   │
 2 │ for i, v in t do
   │     ^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:2:8-9 ──
   │
 2 │ for i, v in t do
   │        ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_5", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x = x + 1
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 4
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_6", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
local y = 5
y, x = y, x + 1
print(y)
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 4
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_7", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x = x + 1
print(x)
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unused_variable_8", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x += 1
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 4
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_9", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x += 1
print(x)
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unused_variable_10", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x += 1
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 4
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_11", function(assert)
		lintTestHelper(assert, {
			content = [[
local function _(x)
	return nil
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:18-19 ──
   │
 1 │ local function _(x)
   │                  ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_12", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
function x()
	return 5
end
x()
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 4
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_13", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
local x = 5
print(x)
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 4
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_14", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
local function x()
	return 5
end
x()
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 4
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_15", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
local x = 5 + x
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:2:7-8 ──
   │
 2 │ local x = 5 + x
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_16", function(assert)
		lintTestHelper(assert, {
			content = [[
local lib = require("whatever")
local _x : lib.num = 3
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unused_variable_17", function(assert)
		lintTestHelper(assert, {
			content = [[
for k, v in t do
	t1[k] = v
end
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unused_variable_18", function(assert)
		lintTestHelper(assert, {
			content = [[
return {
	add = function(a, b)
		return a + b
	end,
}
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
				{ expectedOutput = "Local variable not found in any scope", count = 0 },
			},
		})
	end)

	suite:case("unused_variable_19", function(assert)
		lintTestHelper(assert, {
			content = [[
local T = {}
function T:new()
	self.hello = "world"
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{ expectedOutput = "Local variable not found in any scope", count = 0 },
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local T = {}
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_20", function(assert)
		lintTestHelper(assert, {
			content = [[
local a, b = foo()
a, b = foo()
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 2,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local a, b = foo()
   │       ^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:10-11 ──
   │
 1 │ local a, b = foo()
   │          ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_21", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 3
local y = 1
y = 3, x
print(y)
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local x = 3
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unused_variable_22", function(assert)
		lintTestHelper(assert, {
			content = [[
repeat
	local x = 1
until x == 1
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{ expectedOutput = "Local variable not found in any scope", count = 0 },
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unused_variable_23", function(assert)
		lintTestHelper(assert, {
			content = [=[
for i = 0, num - 1 do
	t.table[lengths[off + i]] += 1
end
    ]=],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unused_variable_24", function(assert)
		lintTestHelper(assert, {
			content = [=[
function foo(t: { num: number })
	t.num = 3
end
    ]=],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("throws error when config has invalid structure", function(assert)
		-- local invalidGlobalConfig = [[
		-- 	return {
		-- 		lute = {
		-- 			lint = {
		-- 				globals = "should be table"
		-- 			}
		-- 		}
		-- 	}
		-- ]]

		local invalidIgnoresConfig = [[
			return {
				lute = {
					lint = {
						ignores = "should be table"
					}
				}
			}
		]]

		-- local invalidRulesConfig = [[
		-- 	return {
		-- 		lute = {
		-- 			lint = {
		-- 				rules = "should be table"
		-- 			}
		-- 		}
		-- 	}
		-- ]]

		local configFile = path.join(tmpDir, ".config.luau")

		-- -- fs.writestringtofile(path.format(configFile), invalidGlobalConfig)
		-- local result = process.run({ lutePath, "lint", "-c", path.format(configFile), path.format(configFile) })
		-- assert.eq(result.exitcode, 1)
		-- assert.strcontains(result.stderr, "config.globals must be a table of [string] : unknown")

		fs.writestringtofile(path.format(configFile), invalidIgnoresConfig)
		local result = process.run({ lutePath, "lint", "-c", path.format(configFile), path.format(configFile) })
		assert.eq(result.exitcode, 1)
		assert.strcontains(result.stderr, "config.lute.lint.ignores must be an array of filepath globs")

		-- fs.writestringtofile(path.format(configFile), invalidRulesConfig)
		-- result = process.run({ lutePath, "lint", "-c", path.format(configFile), path.format(configFile) })
		-- assert.eq(result.exitcode, 1)
		-- assert.strcontains(result.stderr, "config.rules must be a table")
	end)

	suite:case("lute lint accounts for configured ignores (config passed as arg)", function(assert)
		local testSubDir = path.join(tmpDir, "testDir")
		fs.createdirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")
		local notIgnoredFile = path.join(testSubDir, "valid.luau")
		local violatingContents = [[
			a = b
			b = a
			c = 1 / 0
		]]
		fs.writestringtofile(ignoredFile, violatingContents)
		fs.writestringtofile(notIgnoredFile, violatingContents)

		local configFile = path.join(testSubDir, ".config.luau")
		local configContents = [[
		return {
			lute = {
				lint = {
					ignores = { "**/ignored.luau" }
				}
			}
		}
		]]
		fs.writestringtofile(configFile, configContents)

		local result = process.run({ lutePath, "lint", "-c", path.format(configFile), path.format(testSubDir) })
		assert.eq(result.exitcode, 1) -- errors but ONLY from valid.luau
		assert.strnotcontains(result.stdout, "ignored.luau")
		assert.strcontains(result.stdout, "valid.luau")

		fs.removedirectory(testSubDir, {
			recursive = true,
		})
	end)

	suite:case("lute lint accounts for configured ignores (config auto-detected)", function(assert)
		local testSubDir = path.join(tmpDir, "testDir")
		fs.createdirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")

		local violatingContents = [[
			a = b
			b = a
			c = 1 / 0
		]]
		fs.writestringtofile(ignoredFile, violatingContents)

		local configFile = path.join(testSubDir, ".config.luau")
		local configContents = [[
		return {
			lute = {
				lint = {
					ignores = { "**/ignored.luau" }
				}
			}
		}
		]]
		fs.writestringtofile(configFile, configContents)

		local result = process.run({ lutePath, "lint", path.format(testSubDir) }, {
			cwd = path.format(testSubDir),
		})
		assert.eq(result.exitcode, 0) -- no errors
		assert.strnotcontains(result.stdout, "almost_swapped")
		assert.strnotcontains(result.stdout, "divide_by_zero")

		fs.removedirectory(testSubDir, {
			recursive = true,
		})
	end)

	suite:case("lute lint configured ignores supplement (NOT override) existing gitignores", function(assert)
		local testSubDir = path.join(tmpDir, "testDir")
		fs.createdirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")
		local notIgnoredFile = path.join(testSubDir, "valid.luau")
		local violatingContents = "c = 1 / 0"
		fs.writestringtofile(ignoredFile, violatingContents)
		fs.writestringtofile(notIgnoredFile, violatingContents)

		local gitIgnore = path.join(testSubDir, ".gitignore") -- gitignore `valid.luau`
		fs.writestringtofile(
			gitIgnore,
			[[
**/valid.luau
		]]
		)

		local configFile = path.join(testSubDir, ".config.luau") --  configure ignore of `ignored.luau`
		local configContents = [[
		return {
			lute = {
				lint = {
					ignores = { "**/ignored.luau" }
				}
			}
		}
		]]
		fs.writestringtofile(configFile, configContents)

		local result = process.run({ lutePath, "lint", "-c", path.format(configFile), path.format(testSubDir) })
		assert.eq(result.exitcode, 0) -- no errors bc we ignore BOTH files in the dir
		assert.strnotcontains(result.stdout, "almost_swapped")
		assert.strnotcontains(result.stdout, "divide_by_zero")

		fs.removedirectory(testSubDir, {
			recursive = true,
		})
	end)

	suite:case("duplicate_keys list duplicates", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = { 1, 2, [2] = 3 }
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.duplicate_keys,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.duplicate_keys, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:19-26 ──
   │
 1 │ local t = { 1, 2, [2] = 3 }
   │                   ^^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("duplicate_keys record duplicates", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = { a = 1, a = 2 }
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.duplicate_keys,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.duplicate_keys, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:20-25 ──
   │
 1 │ local t = { a = 1, a = 2 }
   │                    ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("duplicate_keys general string duplicates", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = { ["a"] = 1, ["a"] = 2 }
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.duplicate_keys,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.duplicate_keys, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:24-33 ──
   │
 1 │ local t = { ["a"] = 1, ["a"] = 2 }
   │                        ^^^^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("duplicate_keys general number duplicates", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = { [1] = 1, [1] = 2 }
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.duplicate_keys,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.duplicate_keys, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:22-29 ──
   │
 1 │ local t = { [1] = 1, [1] = 2 }
   │                      ^^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("duplicate_keys general number clashes with array part", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = { 1, 2, [2] = 3 }
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.duplicate_keys,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.duplicate_keys, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:19-26 ──
   │
 1 │ local t = { 1, 2, [2] = 3 }
   │                   ^^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("duplicate_keys general string and record entry duplicates", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = { ["a"] = 1, a = 2 }
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.duplicate_keys,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.duplicate_keys, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:24-29 ──
   │
 1 │ local t = { ["a"] = 1, a = 2 }
   │                        ^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("duplicate_keys doesn't warn on general 0", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = { [0] = 1 }
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.duplicate_keys,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.duplicate_keys, count = 0 },
			},
		})
	end)
end)
