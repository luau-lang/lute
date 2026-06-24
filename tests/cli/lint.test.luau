local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local tableext = require("@std/tableext")
local test = require("@std/test")
local testTypes = require("@std/test/types")
local testutil = require("../testutil")

local lutePath = path.format(process.execPath())
local tmpDir = system.tmpdir()
local rulesDir = path.format(path.join(tmpDir, "lints"))
local defaultRulesFolder = path.format(path.join("lute", "cli", "commands", "lint", "rules"))
local defaultRulesPaths = {
	almost_swapped = path.format(path.join(defaultRulesFolder, "almost_swapped.luau")),
	constant_table_comparison = path.format(path.join(defaultRulesFolder, "constant_table_comparison.luau")),
	divide_by_zero = path.format(path.join(defaultRulesFolder, "divide_by_zero.luau")),
	duplicate_keys = path.format(path.join(defaultRulesFolder, "duplicate_keys.luau")),
	empty_if_block = path.format(path.join(defaultRulesFolder, "empty_if_block.luau")),
	global_function_in_scope = path.format(path.join(defaultRulesFolder, "global_function_in_scope.luau")),
	no_any = path.format(path.join(defaultRulesFolder, "no_any.luau")),
	parenthesized_conditions = path.format(path.join(defaultRulesFolder, "parenthesized_conditions.luau")),
	unused_variable = path.format(path.join(defaultRulesFolder, "unused_variable.luau")),
}

local LINT_RULE_MESSAGES = {
	almost_swapped = "warning[almost_swapped]: This looks like a failed attempt to swap.",
	constant_table_comparison = "warning[constant_table_comparison]: Constant table comparison detected. Comparing a table reference to a table literal will always evaluate to false.",
	divide_by_zero = "warning[divide_by_zero]: Division by zero detected.",
	duplicate_keys = "warning[duplicate_keys]: Duplicate keys detected in table literal.",
	empty_if_block = "warning[empty_if_block]: Empty if block detected. Consider removing it or adding to it.",
	global_function_in_scope = "warning[global_function_in_scope]: Non-local function declaration found inside a nested scope. Use 'local function' instead, or move this to the top level.",
	no_any = "warning[no_any]: Explicit 'any' type detected. Use 'unknown' for type-safe alternatives that require narrowing before use.",
	parenthesized_conditions = "info[parenthesized_conditions]: Luau doesn't require parentheses around conditions. You can remove them for readability.",
	unused_variable = "warning[unused_variable]: Unused variable detected. Prefix this variable with '_' to indicate that it's intentionally unused.",
}

local USAGE = "Usage: lute lint [OPTIONS] [...PATHS]"

local LUAURC_CONTENT = [[
{
    "aliases": {
        "lint": "@std/commands/lint/types"
    }
}
]]

local function runProcess(args: { string }, options: process.ProcessRunOptions?): process.ProcessResult
	local result = process.run(args, options)
	result.stdout = testutil.normalizeLineEndings(result.stdout)
	result.stderr = testutil.normalizeLineEndings(result.stderr)
	return result
end

type lintTestParams = {
	content: string,
	expectedExitCode: number,
	returnStdErr: true?,
	rulePath: string?,
	processOptions: process.ProcessRunOptions?,
	customRuleContents: string?,
	expectedAutofixContents: string?,
	disableDefaultLints: true?,
	configContents: string?,
	extraOptions: { string }?,
	outputExpectations: { { expectedOutput: string, count: number? } }?,
}

type Mode = "parallel" | "sequential"

local executionModeArgs: { [Mode]: { string } } = {
	sequential = { "--sequential" },
	parallel = {},
}

local function lintTestHelper(assert: testTypes.Asserts, params: lintTestParams): string
	-- Setup
	-- Create a file that violates the rule
	local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
	fs.writeStringToFile(violatorPath, params.content)

	-- Do
	local lintArgs = { lutePath, "lint" }

	if params.rulePath and params.customRuleContents then
		error("Cannot specify both rulePath and customRuleContents")
	elseif params.rulePath then
		table.insert(lintArgs, "-r")
		table.insert(lintArgs, params.rulePath)
	elseif params.customRuleContents then
		local customRulePath = path.format(path.join(tmpDir, "custom_rule.luau"))
		fs.writeStringToFile(customRulePath, params.customRuleContents)
		table.insert(lintArgs, "-r")
		table.insert(lintArgs, customRulePath)
	end

	if params.expectedAutofixContents then
		table.insert(lintArgs, "--auto-fix")
	end

	if params.disableDefaultLints then
		table.insert(lintArgs, "--no-default-lints")
	end

	-- Create a config file if specified
	if params.configContents then
		local configPath = path.format(path.join(tmpDir, ".config.luau"))
		fs.writeStringToFile(configPath, params.configContents)
		table.insert(lintArgs, "-c")
		table.insert(lintArgs, configPath)
	end

	if params.extraOptions then
		tableext.extend(lintArgs, params.extraOptions)
	end

	table.insert(lintArgs, violatorPath)

	local results: { [Mode]: process.ProcessResult } = {
		parallel = nil :: never,
		sequential = nil :: never,
	}

	for mode, args in executionModeArgs do
		local modeArgs = table.clone(lintArgs)
		tableext.extend(modeArgs, args)
		local result = runProcess(modeArgs, params.processOptions)

		results[mode] = result

		-- Check
		assert.eq(result.exitcode, params.expectedExitCode)

		if params.expectedAutofixContents then
			local fixedContents = fs.readFileToString(violatorPath)
			assert.eq(fixedContents, params.expectedAutofixContents)
		end

		if params.outputExpectations then
			for _, expectation in params.outputExpectations do
				if expectation.count == 0 then
					assert.strNotContains(result.stdout, expectation.expectedOutput)
				else
					assert.strContains(result.stdout, expectation.expectedOutput, expectation.count)
				end
			end
		end
	end

	assert.eq(results.parallel, results.sequential)

	return if params.returnStdErr then results.parallel.stderr else results.parallel.stdout
end

test.suite("lute lint", function(suite)
	suite:beforeEach(function()
		-- A test that creates rulesDir which fails won't cleanup after itself
		if fs.exists(rulesDir) then
			fs.removeDirectory(rulesDir, { recursive = true })
		end

		local modulePath = path.join(tmpDir, "module")
		if fs.exists(modulePath) then
			fs.removeDirectory(modulePath, { recursive = true })
		end
	end)

	suite:afterEach(function()
		local configPath = path.format(path.join(tmpDir, ".config.luau"))
		if fs.exists(configPath) then
			fs.remove(configPath)
		end
	end)

	suite:case("luteLintHelpMessage", function(assert)
		local result = runProcess({ lutePath, "lint", "-h" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)

		result = runProcess({ lutePath, "lint", "--h" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)

		result = runProcess({ lutePath, "lint", "--help" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)
	end)

	suite:case("luteLintErrorCode0WithNoViolations", function(assert)
		local output = lintTestHelper(assert, { content = "", expectedExitCode = 0 })

		assert.eq(output, "")
	end)

	suite:case("luteLintVerbose", function(assert)
		local output = lintTestHelper(assert, {
			content = "",
			expectedExitCode = 0,
			extraOptions = { "-v" },
			outputExpectations = {
				{ expectedOutput = "Applying lint rules", count = 1 },
				{ expectedOutput = "Printing violations from 0 files", count = 1 },
			},
		})

		assert.neq(output:find("Reading input file '.+violator%.luau'"), nil)
		assert.neq(output:find("Parsing input file '.+violator%.luau'"), nil)
	end)

	suite:case("divideByZero", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 1 / 0
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			disableDefaultLints = true,
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

	suite:case("divideByZeroAutoFix", function(assert)
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
local _z = math.nan
local _nan = math.nan
local _negnan = math.nan
]],
		})
	end)

	suite:case("almostSwapped", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("almostSwappedAutoFix", function(assert)
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

	suite:case("luteLintCustomRulesDir", function(assert)
		-- Setup
		fs.createDirectory(rulesDir)
		fs.writeStringToFile(path.join(rulesDir, ".luaurc"), LUAURC_CONTENT)
		-- Copy almostSwapped.luau to rulesDir/almostSwapped.luau
		fs.copy(defaultRulesPaths.almost_swapped, path.join(rulesDir, "almost_swapped.luau"))
		-- Copy divide_by_zero to rulesDir/divide_by_zero/init.luau
		local divideByZeroDir = path.join(rulesDir, "divide_by_zero")
		fs.createDirectory(divideByZeroDir)
		fs.copy(defaultRulesPaths.divide_by_zero, path.join(divideByZeroDir, "init.luau"))
		fs.writeStringToFile(
			path.join(rulesDir, "bogus.txt"),
			[[
not a luau file
]]
		)

		lintTestHelper(assert, {
			content = [[
local x = 1 / 0

a = b
b = a
]],
			expectedExitCode = 1,
			rulePath = rulesDir,
			disableDefaultLints = true,
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
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 1 },
			},
		})

		fs.removeDirectory(rulesDir, { recursive = true })
	end)

	suite:case("luteLintMultipleRulesButOneErrors", function(assert)
		-- Setup
		fs.createDirectory(rulesDir)
		fs.writeStringToFile(path.join(rulesDir, ".luaurc"), LUAURC_CONTENT)
		-- Copy almostSwapped.luau to rulesDir/almostSwapped.luau
		fs.copy(defaultRulesPaths.almost_swapped, path.join(rulesDir, "almost_swapped.luau"))
		-- Create a rule that fails
		fs.writeStringToFile(
			path.join(rulesDir, "erroring_rule.luau"),
			[[
return table.freeze({
	name = "AlwaysErrors",
	lint = function(cst, sourcepath)
		error("This rule always errors")
	end,
})
]]
		)

		local output = lintTestHelper(assert, {
			content = [[a = b
b = a
]],
			expectedExitCode = 1,
			rulePath = rulesDir,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 1 },
				{
					expectedOutput = [[violator.luau:1:1-2:6 ──
   │
 1 │ ╭ a = b
 2 │ │ b = a
   │ ╰─────^
   │
]],
					count = 1,
				},
			},
		})

		assert.neq(
			output:find(
				"Error applying lint rule 'AlwaysErrors': .+[/\\]lints[/\\]erroring_rule%.luau:4: This rule always errors",
				1
			),
			nil
		)

		-- Teardown
		fs.removeDirectory(rulesDir, { recursive = true })
	end)

	suite:case("luteLintMultipleInputFiles", function(assert)
		-- Setup
		-- Create multiple files that violate the rule
		local violatorPath1 = path.format(path.join(tmpDir, "violator1.luau"))
		fs.writeStringToFile(
			violatorPath1,
			[[
local x = 1 / 0

a = b
b = a
    ]]
		)

		local modulePath = path.join(tmpDir, "module")
		fs.createDirectory(modulePath)
		local violatorPath2 = path.format(path.join(modulePath, "violator2.lua"))
		fs.writeStringToFile(
			violatorPath2,
			[[
local y = 10 / 0

local x = 0
local y = "hello"
x = y
y = x
    ]]
		)
		fs.writeStringToFile(path.format(path.join(modulePath, "not_luau.txt")), "blablabla")

		-- Do
		-- Run the transformer on the transformee
		local result = runProcess({ lutePath, "lint", "-v", violatorPath1, path.format(modulePath) })

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
		assert.strContains(result.stdout, expected)

		expected = [[
violator2.lua:1:11-17 ──
   │
 1 │ local y = 10 / 0
   │           ^^^^^^
   │
]]
		assert.strContains(result.stdout, expected)

		assert.eq(#result.stdout:split(LINT_RULE_MESSAGES.almost_swapped), 3)
		expected = [[
violator1.luau:3:1-4:6 ──
   │
 3 │ ╭ a = b
 4 │ │ b = a
   │ ╰─────^
   │
]]
		assert.strContains(result.stdout, expected)

		expected = [[
violator2.lua:5:1-6:6 ──
   │
 5 │ ╭ x = y
 6 │ │ y = x
   │ ╰─────^
   │
]]
		assert.strContains(result.stdout, expected)
		expected = "Skipping non%-Luau file '.+[/\\]module[/\\]not_luau%.txt'"
		assert.neq(result.stdout:find(expected, 1, false), nil)

		-- Teardown
		fs.remove(violatorPath1)
		fs.removeDirectory(modulePath, { recursive = true })
	end)

	suite:case("luteLintMultipleFilesWithErrorsRecovers", function(assert)
		-- Setup
		-- Create multiple files that violate the rule
		local lintee = path.format(path.join(tmpDir, "lintee.luau"))
		fs.writeStringToFile(lintee, "bogus")

		local violatorPath = path.format(path.join(tmpDir, "violator1.luau"))
		fs.writeStringToFile(
			violatorPath,
			[[
local x = 1 / 0

a = b
b = a
    ]]
		)

		-- Do
		-- Run the transformer on the transformee
		local result = runProcess({ lutePath, "lint", lintee, violatorPath })

		-- Check
		assert.eq(result.exitcode, 1)

		local expected = [[
lintee.luau': @std/syntax/parser.luau:12: parsing failed:
(0, 0) - (0, 5): Incomplete statement: expected assignment or a function call
]]
		assert.strContains(result.stdout, expected)

		assert.strContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
		assert.strContains(result.stdout, LINT_RULE_MESSAGES.almost_swapped)

		-- Teardown
		fs.remove(lintee)
		fs.remove(violatorPath)
	end)

	suite:case("luteLintDefaultRules", function(assert)
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

	suite:case("luteLintWarningSuppression", function(assert)
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

	suite:case("suppressionIsLimitedToFollowingStatement", function(assert)
		lintTestHelper(assert, {
			content = [[
-- lute-lint-ignore(divide_by_zero)
local x = 1 / 0

if true then
	local y = 10 / 0
end

local z = 1 / 0
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.divide_by_zero,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.divide_by_zero, count = 2 },
				{
					expectedOutput = [[
violator.luau:5:12-18 ──
   │
 5 │     local y = 10 / 0
   │               ^^^^^^
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

	suite:case("suppressionIsLimitedToFollowingStatement2", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("suppressionIsLimitedToFollowingStatement3", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("suppressionIsLimitedToFollowingStatement4", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("suppressionIsLimitedToFollowingStatement5", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("suppressionIsLimitedToFollowingStatement6", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("suppressionForMultiNodeViolation", function(assert)
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

	suite:case("suppressionForMultiNodeViolationPartial", function(assert)
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

	suite:case("nestedSuppressions", function(assert)
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

	suite:case("jsonOutput", function(assert)
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
                    "tags": [
                        1
                    ],
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

	suite:case("luteLintRespectsGitignore", function(assert)
		-- Setup
		-- Create a module directory with a .gitignore that ignores one file
		local modulePath = path.join(tmpDir, "module")
		fs.createDirectory(modulePath)
		local violatorPath1 = path.format(path.join(modulePath, "violator1.luau"))
		fs.writeStringToFile(
			violatorPath1,
			[[
local x = 10 / 0
    ]]
		)
		local violatorPath2 = path.format(path.join(modulePath, "violator2.luau"))
		fs.writeStringToFile(
			violatorPath2,
			[[
local y = 10 / 0
    ]]
		)
		fs.writeStringToFile(path.format(path.join(modulePath, ".gitignore")), "violator2.luau\n")

		-- Do
		-- Run the transformer on the transformee
		local result = runProcess({ lutePath, "lint", path.format(modulePath) })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero, 1)
		local expected = [[
violator1.luau:1:11-17 ──
   │
 1 │ local x = 10 / 0
   │           ^^^^^^
   │
]]
		assert.strContains(result.stdout, expected)

		expected = [[
violator2.lua:1:11-17 ──
   │
 1 │ local y = 10 / 0
   │           ^^^^^^
   │
]]
		assert.strNotContains(result.stdout, expected)

		-- Teardown
		fs.removeDirectory(modulePath, { recursive = true })
	end)

	suite:case("luteLintReportDirective", function(assert)
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

	suite:case("luteLintGlobalIgnoreDirective", function(assert)
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

	suite:case("luteLintStringInput", function(assert)
		local inputString = [[
a = b
b = a
]]

		-- Do
		-- Run the linter on string input
		local result = runProcess({ lutePath, "lint", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strContains(result.stdout, LINT_RULE_MESSAGES.almost_swapped)
		local expected = [[
   ┌── input:1:1-2:6 ──
   │
 1 │ ╭ a = b
 2 │ │ b = a
   │ ╰─────^
   │
]]
		assert.strContains(result.stdout, expected)
	end)

	suite:case("luteLintStringInputVerbose", function(assert)
		local inputString = "local x = 1 / 0"

		-- Do
		-- Run the linter on string input with verbose flag
		local result = runProcess({ lutePath, "lint", "-v", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 1)

		assert.strContains(result.stdout, "Parsing input string")
		assert.strContains(result.stdout, "Parsing global lint ignores in input string")
		assert.strContains(result.stdout, "Applying lint rules")
		assert.strContains(result.stdout, "Printing violations from string input")
		assert.strContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
	end)

	suite:case("luteLintStringInputWithNoViolations", function(assert)
		local inputString = "x = 1 + 2"

		-- Do
		-- Run the linter on string input
		local result = runProcess({ lutePath, "lint", "-v", "-s", inputString })

		-- Check
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "No lint violations found.")
	end)

	suite:case("luteLintStringInputJsonOutput", function(assert)
		local inputString = "local x = 1 / 0"

		-- Do
		-- Run the linter on string input with json flag
		local result = runProcess({ lutePath, "lint", "-j", "-s", inputString })

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
        "tags": [
            1
        ],
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
		assert.strContains(result.stdout, expected)
	end)

	suite:case("luteLintIgnoreTableItem", function(assert)
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

	suite:case("parenthesizedConditions", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("parenthesizedConditionsAutoFix", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("reportViolationsRemainingAfterAutoFix", function(assert)
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

	suite:case("constantTableComparison", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("constantTableComparisonAutoFix", function(assert)
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
			disableDefaultLints = true,
			expectedAutofixContents = [[
local a = next(t) == nil
local b = next(t) == nil
local c = next(t) == nil
local d = next(t) == nil
local e = next(t) ~= nil
]],
		})
	end)

	suite:case("luteLintJsonOutputIncludesSuggestedfix", function(assert)
		local inputString = [[
			a = b
			b = a
		]]

		-- Do
		-- Run the linter on string input with json flag
		local result = runProcess({ lutePath, "lint", "-j", "-s", inputString })

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
		assert.strContains(result.stdout, expected)
	end)

	suite:case("noAny", function(assert)
		lintTestHelper(assert, {
			content = [[
local _x: any = 5
local _y: unknown = 5
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.no_any, count = 1 },
			},
		})
	end)

	suite:case("noAnyFunctionParameter", function(assert)
		lintTestHelper(assert, {
			content = [[
local function _f(_x: any, _y: unknown)
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.no_any, count = 1 },
			},
		})
	end)

	suite:case("noAnyReturnType", function(assert)
		lintTestHelper(assert, {
			content = [[
local function _f(): any
	return nil
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.no_any, count = 1 },
			},
		})
	end)

	suite:case("noAnyTypeAlias", function(assert)
		lintTestHelper(assert, {
			content = [[
type _T = any
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.no_any, count = 1 },
			},
		})
	end)

	suite:case("noAnyMultipleViolations", function(assert)
		lintTestHelper(assert, {
			content = [[
local _x: any = 5
local function _f(_y: any): any
	return nil
end
type _T = any
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.no_any, count = 4 },
			},
		})
	end)

	suite:case("noAnyNoFalsePositiveOnPrefixed", function(assert)
		lintTestHelper(assert, {
			content = [[
type _T = module.any
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
		})
	end)

	suite:case("noAnyNoFalsePositiveOnUnknown", function(assert)
		lintTestHelper(assert, {
			content = [[
local _x: unknown = 5
local function _f(_y: unknown): unknown
	return nil
end
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
		})
	end)

	suite:case("noAnyAutoFix", function(assert)
		lintTestHelper(assert, {
			content = [[
local _x: any = 5
local function _f(_y: any): any
	return nil
end
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.no_any,
			disableDefaultLints = true,
			expectedAutofixContents = [[
local _x: unknown = 5
local function _f(_y: unknown): unknown
	return nil
end
]],
		})
	end)

	suite:case("unusedVariable1", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 3
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable2", function(assert)
		lintTestHelper(assert, {
			content = [[
local _ = 3
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariable3", function(assert)
		lintTestHelper(assert, {
			content = [[
for i = 3, 4 do
	print(3)
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable4", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = {1, 2, 3}
for i, v in t do
	print(3)
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable5", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x = x + 1
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable6", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
local y = 5
y, x = y, x + 1
print(y)
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable7", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x = x + 1
print(x)
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariable8", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x += 1
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable9", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x += 1
print(x)
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariable10", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
x += 1
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable11", function(assert)
		lintTestHelper(assert, {
			content = [[
local function _(x)
	return nil
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable12", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("unusedVariable13", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
local x = 5
print(x)
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable14", function(assert)
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
			disableDefaultLints = true,
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

	suite:case("unusedVariable15", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 4
local x = 5 + x
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable16", function(assert)
		lintTestHelper(assert, {
			content = [[
local lib = require("whatever")
local _x : lib.num = 3
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariable17", function(assert)
		lintTestHelper(assert, {
			content = [[
for k, v in t do
	t1[k] = v
end
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariable18", function(assert)
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
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
				{ expectedOutput = "Local variable not found in any scope", count = 0 },
			},
		})
	end)

	suite:case("unusedVariable19", function(assert)
		lintTestHelper(assert, {
			content = [[
local T = {}
function T:new()
	self.hello = "world"
end
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable20", function(assert)
		lintTestHelper(assert, {
			content = [[
local a, b = foo()
a, b = foo()
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable21", function(assert)
		lintTestHelper(assert, {
			content = [[
local x = 3
local y = 1
y = 3, x
print(y)
    ]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
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

	suite:case("unusedVariable22", function(assert)
		lintTestHelper(assert, {
			content = [[
repeat
	local x = 1
until x == 1
    ]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = "Local variable not found in any scope", count = 0 },
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariable23", function(assert)
		lintTestHelper(assert, {
			content = [=[
for i = 0, num - 1 do
	t.table[lengths[off + i]] += 1
end
    ]=],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariable24", function(assert)
		lintTestHelper(assert, {
			content = [=[
function foo(t: { num: number })
	t.num = 3
end
    ]=],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 0,
				},
			},
		})
	end)

	suite:case("unusedVariableWithTableInsertDefaultWriteOnlyApi", function(assert)
		lintTestHelper(assert, {
			content = [[
local t = {}
table.insert(t, 1)
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local t = {}
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableWithCustomWriteOnlyApiSingleLevel", function(assert)
		lintTestHelper(assert, {
			content = [[
local output = {}
myWrite(output, "data")
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["unused_variable"] = {
					options = {
						myWrite = { 1 }
					}
				}
			}
		}
	}
}
			]],
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-13 ──
   │
 1 │ local output = {}
   │       ^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableWithCustomWriteOnlyApiNested", function(assert)
		lintTestHelper(assert, {
			content = [[
local buffer = {}
fs.write(buffer, "content")
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["unused_variable"] = {
					options = {
						["fs.write"] = { 1 }
					}
				}
			}
		}
	}
}
			]],
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-13 ──
   │
 1 │ local buffer = {}
   │       ^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableWithCustomWriteOnlyApiNestedIndexExprAccess", function(assert)
		lintTestHelper(assert, {
			content = [[
local buffer = {}
fs["write"](buffer, "content")
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["unused_variable"] = {
					options = {
						["fs.write"] = { 1 }
					}
				}
			}
		}
	}
}
			]],
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:1:7-13 ──
   │
 1 │ local buffer = {}
   │       ^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableWithMultipleWriteOnlyArgs", function(assert)
		lintTestHelper(assert, {
			content = [[
local a = {}
local b = {}
myMultiWrite(a, b, "data")
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["unused_variable"] = {
					options = {
						myMultiWrite = { 1, 2 }
					}
				}
			}
		}
	}
}
			]],
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 2,
				},
				{
					expectedOutput = [[
violator.luau:1:7-8 ──
   │
 1 │ local a = {}
   │       ^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:2:7-8 ──
   │
 2 │ local b = {}
   │       ^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableWithWriteOnlyArgAtPosition2", function(assert)
		lintTestHelper(assert, {
			content = [[
local config = "read"
local output = {}
myFunc(config, output)
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["unused_variable"] = {
					options = {
						myFunc = { 2 }
					}
				}
			}
		}
	}
}
			]],
			outputExpectations = {
				{
					expectedOutput = LINT_RULE_MESSAGES.unused_variable,
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:2:7-13 ──
   │
 2 │ local output = {}
   │       ^^^^^^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableWithDeepNestingErrors", function(assert)
		lintTestHelper(assert, {
			content = "local x = 1",
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["unused_variable"] = {
					options = {
						["deeply.nested.api"] = { 1 }
					}
				}
			}
		}
	}
}
			]],
			outputExpectations = {
				{
					expectedOutput = "Invalid API 'deeply.nested.api' in options. Only APIs up to 2 levels deep are supported.",
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableWithConflictingApiDefinitionsErrors", function(assert)
		lintTestHelper(assert, {
			content = "local x = 1",
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
			configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["unused_variable"] = {
					options = {
						myApi = { 1 },
						["myApi.nested"] = { 1 }
					}
				}
			}
		}
	}
}
			]],
			outputExpectations = {
				{
					expectedOutput = "API 'myApi' is already defined as part of a write-only API, so 'myApi' cannot be added as a write-only API.",
					count = 1,
				},
			},
		})
	end)

	suite:case("unusedVariableRegressionTest", function(assert)
		lintTestHelper(assert, {
			content = [[
local A = {}
local _ = require(A.Index)
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.unused_variable,
			disableDefaultLints = true,
		})
	end)

	suite:case("throwsErrorWhenConfigHasInvalidGlobals", function(assert)
		local err = lintTestHelper(assert, {
			content = "",
			configContents = [[
			return {
				lute = {
					lint = {
						globals = "should be table"
					}
				}
			}
		]],
			expectedExitCode = 1,
			returnStdErr = true,
		})
		assert.strContains(err, "config.lute.lint.globals must be a table with string keys")
	end)

	suite:case("throwsErrorWhenConfigHasInvalidIgnores", function(assert)
		local err = lintTestHelper(assert, {
			content = "",
			configContents = [[
			return {
				lute = {
					lint = {
						ignores = "should be table"
					}
				}
			}
		]],
			expectedExitCode = 1,
			returnStdErr = true,
		})
		assert.strContains(err, "config.lute.lint.ignores must be an array of filepath globs")
	end)

	suite:case("throwsErrorWhenConfigHasInvalidRulePaths", function(assert)
		local err = lintTestHelper(assert, {
			content = "",
			configContents = [[
			return {
				lute = {
					lint = {
						rulepaths = "should be table"
					}
				}
			}
		]],
			expectedExitCode = 1,
			returnStdErr = true,
		})
		assert.strContains(err, "config.lute.lint.rulepaths must be an array of filepath globs")
	end)

	suite:case("throwsErrorWhenConfigHasInvalidRuleConfigs", function(assert)
		local err = lintTestHelper(assert, {
			content = "",
			configContents = [[
			return {
				lute = {
					lint = {
						ruleconfigs = "should be table"
					}
				}
			}
		]],
			expectedExitCode = 1,
			returnStdErr = true,
		})
		assert.strContains(err, "config.lute.lint.ruleconfigs must be a table with string keys")
	end)

	suite:case("luteLintAccountsForConfiguredIgnoresConfigPassedAsArg", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")
		local notIgnoredFile = path.join(testSubDir, "valid.luau")
		local violatingContents = [[
			a = b
			b = a
			c = 1 / 0
		]]
		fs.writeStringToFile(ignoredFile, violatingContents)
		fs.writeStringToFile(notIgnoredFile, violatingContents)

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
		fs.writeStringToFile(configFile, configContents)

		local result = runProcess({ lutePath, "lint", "-c", path.format(configFile), path.format(testSubDir) })
		assert.eq(result.exitcode, 1) -- errors but ONLY from valid.luau
		assert.strNotContains(result.stdout, "ignored.luau")
		assert.strContains(result.stdout, "valid.luau")
	end)

	suite:case("luteLintAccountsForConfiguredIgnoresConfigAutoDetected", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")

		local violatingContents = [[
			a = b
			b = a
			c = 1 / 0
		]]
		fs.writeStringToFile(ignoredFile, violatingContents)

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
		fs.writeStringToFile(configFile, configContents)

		local result = runProcess({ lutePath, "lint", path.format(testSubDir) }, {
			cwd = path.format(testSubDir),
		})
		assert.eq(result.exitcode, 0) -- no errors
		assert.strNotContains(result.stdout, "almost_swapped")
		assert.strNotContains(result.stdout, "divide_by_zero")
	end)

	suite:case("luteLintConfiguredIgnoresSupplementNotOverrideExistingGitignores", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")
		local notIgnoredFile = path.join(testSubDir, "valid.luau")
		local violatingContents = "c = 1 / 0"
		fs.writeStringToFile(ignoredFile, violatingContents)
		fs.writeStringToFile(notIgnoredFile, violatingContents)

		local gitIgnore = path.join(testSubDir, ".gitignore") -- gitignore `valid.luau`
		fs.writeStringToFile(
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
		fs.writeStringToFile(configFile, configContents)

		local result = runProcess({ lutePath, "lint", "-c", path.format(configFile), path.format(testSubDir) })
		assert.eq(result.exitcode, 0) -- no errors bc we ignore BOTH files in the dir
		assert.strNotContains(result.stdout, "almost_swapped")
		assert.strNotContains(result.stdout, "divide_by_zero")
	end)

	suite:case("luteLintSupportsConfiguredDirectoryIgnores", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		-- Create a nested directory structure with violating files
		local nestedDir = path.join(testSubDir, "shouldBeIgnored")
		fs.createDirectory(nestedDir)

		local file1 = path.join(nestedDir, "file1.luau")
		local file2 = path.join(nestedDir, "file2.luau")
		local file3 = path.join(testSubDir, "notIgnored.luau")

		local violatingContents = [[
			a = b
			b = a
			c = 1 / 0
		]]
		fs.writeStringToFile(file1, violatingContents)
		fs.writeStringToFile(file2, violatingContents)
		fs.writeStringToFile(file3, violatingContents)

		local configFile = path.join(testSubDir, ".config.luau")
		local configContents = [[
		return {
			lute = {
				lint = {
					ignores = { "**/shouldBeIgnored/**" }
				}
			}
		}
		]]
		fs.writeStringToFile(configFile, configContents)

		local result = runProcess({ lutePath, "lint", "-c", path.format(configFile), path.format(testSubDir) })
		assert.eq(result.exitcode, 1) -- errors but ONLY from notIgnored.luau

		-- Should NOT contain violations from the ignored directory
		assert.strNotContains(result.stdout, "file1.luau")
		assert.strNotContains(result.stdout, "file2.luau")

		-- Should contain violations from the non-ignored file
		assert.strContains(result.stdout, "notIgnored.luau")
		assert.strContains(result.stdout, "divide_by_zero")
		assert.strContains(result.stdout, "almost_swapped")
	end)

	suite:case("luteLintHandlesIgnoresWithRelativeConfigPath", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")
		local notIgnoredFile = path.join(testSubDir, "valid.luau")
		local violatingContents = [[
			a = b
			b = a
			c = 1 / 0
		]]
		fs.writeStringToFile(ignoredFile, violatingContents)
		fs.writeStringToFile(notIgnoredFile, violatingContents)

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
		fs.writeStringToFile(configFile, configContents)

		-- Pass config as a relative path, setting cwd to ensure relative config path is correct
		local result = runProcess({ lutePath, "lint", "-c", ".config.luau", "." }, {
			cwd = path.format(testSubDir),
		})
		assert.eq(result.exitcode, 1) -- errors but ONLY from valid.luau
		assert.strNotContains(result.stdout, "ignored.luau")
		assert.strContains(result.stdout, "valid.luau")
	end)

	suite:case("luteLintHandlesIgnoresWithAbsoluteConfigPath", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local ignoredFile = path.join(testSubDir, "ignored.luau")
		local notIgnoredFile = path.join(testSubDir, "valid.luau")
		local violatingContents = [[
			a = b
			b = a
			c = 1 / 0
		]]
		fs.writeStringToFile(ignoredFile, violatingContents)
		fs.writeStringToFile(notIgnoredFile, violatingContents)

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
		fs.writeStringToFile(configFile, configContents)

		-- Pass config as an absolute path, with cwd set to a different directory (homedir)
		local result = runProcess({ lutePath, "lint", "-c", path.format(configFile), path.format(testSubDir) })
		assert.eq(result.exitcode, 1) -- errors but ONLY from valid.luau
		assert.strNotContains(result.stdout, "ignored.luau")
		assert.strContains(result.stdout, "valid.luau")
	end)

	suite:case("luteLintPassesContextThroughToRules", function(assert)
		-- custom rule that returns violating with globals and options in the message
		local customRuleContents = [[
			return {
				name = "testRule",
				lint = function(cst, sourcepath, context)
					return {
						{
							lintname = "testRule",
							location = cst.location,
							severity = "warn",
							message = `Globals: {context.globals["testGlobal"]} Options: {context.options["testOption"]}`
						}
					}
				end
			}
		]]

		local configContents = [[
		return {
			lute = {
				lint = {
					globals = {
						["testGlobal"] = 1,
					},
					ruleconfigs = {
						["testRule"] = {
							options = {
								["testOption"] = "nice",
							}
						}
					}
				}
			}
		}
		]]

		lintTestHelper(assert, {
			content = "local x = 1",
			expectedExitCode = 1,
			customRuleContents = customRuleContents,
			configContents = configContents,
			disableDefaultLints = true,
			outputExpectations = { { expectedOutput = "Globals: 1 Options: nice", count = 1 } },
		})
	end)

	suite:case("luteLintAccountsForRuleSpecificIgnores", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local violatorFile = path.join(testSubDir, "violator.luau")
		fs.writeStringToFile(
			violatorFile,
			[[
		local x = 1 / 0
		local a, b
		a = b
		b = a
]]
		)

		local configFile = path.join(testSubDir, ".config.luau")
		local configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["divide_by_zero"] = {
					ignores = { "**/violator.luau" }
				}
			}
		}
	}
}
]]
		fs.writeStringToFile(configFile, configContents)

		-- assert that violations are present without config
		local result = runProcess({ lutePath, "lint", path.format(violatorFile) }, {
			cwd = path.format(process.homedir()),
		})
		assert.eq(result.exitcode, 1) -- should be violations
		assert.strContains(result.stdout, "violator.luau")
		assert.strContains(result.stdout, "[divide_by_zero]")
		assert.strContains(result.stdout, "[almost_swapped]")

		-- with config, there should be violations but NOT for divide_by_zero
		result = runProcess({ lutePath, "lint", "-c", path.format(configFile), path.format(violatorFile) }, {
			cwd = path.format(process.homedir()),
		})
		assert.eq(result.exitcode, 1)
		assert.strNotContains(result.stdout, "[divide_by_zero]")
		assert.strContains(result.stdout, "[almost_swapped]")
	end)

	suite:case("luteLintAccountsForRuleSpecificDirectoryIgnores", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local ignoredDir = path.join(testSubDir, "ignoredDir")
		fs.createDirectory(ignoredDir)

		local ignoredFile = path.join(ignoredDir, "violator.luau")
		local notIgnoredFile = path.join(testSubDir, "nonIgnored.luau")

		local violatingContents = [[
local x = 1 / 0
local a, b
a = b
b = a
]]
		fs.writeStringToFile(ignoredFile, violatingContents)
		fs.writeStringToFile(notIgnoredFile, violatingContents)

		local configFile = path.join(testSubDir, ".config.luau")
		local configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["divide_by_zero"] = {
					ignores = { "**/ignoredDir/**" }
				}
			}
		}
	}
}
]]
		fs.writeStringToFile(configFile, configContents)

		local result = runProcess({ lutePath, "lint", "-c", path.format(configFile), path.format(testSubDir) })
		assert.eq(result.exitcode, 1)

		-- Both files should still report almost_swapped (the non-ignored rule)
		assert.strContains(result.stdout, "[almost_swapped]", 2)

		-- Only 1 divide_by_zero: from the non-ignored file, not from ignoredDir
		assert.strContains(result.stdout, "[divide_by_zero]", 1)
		assert.strContains(result.stdout, "nonIgnored.luau:1:11-16") -- the non-ignored file's violation
	end)

	suite:case("defaultRulesConfiguredWithOffDoNotRun", function(assert)
		local violationContents = [[
			a = b
			b = a
		]]

		local configContents = [[
		return {
			lute = {
				lint = {
					ruleconfigs = {
						["almost_swapped"] = {
							off = true,
						}
					}
				}
			}
		}
		]]

		lintTestHelper(assert, {
			content = violationContents,
			expectedExitCode = 0,
			configContents = configContents,
			outputExpectations = { { expectedOutput = LINT_RULE_MESSAGES.almost_swapped, count = 0 } },
		})
	end)

	suite:case("customRulesConfiguredWithOffDoNotRun", function(assert)
		local customRuleContents = [[
		return {
			name = "customRule",
			lint = function(cst, _sourcepath, _context)
				return {
					{
						lintname = "customRule",
						severity = "warning",
						message = "customRule",
						location = cst.location,
					}
				}
			end
		}
		]]

		local configContents = [[
		return {
			lute = {
				lint = {
					ruleconfigs = {
						["customRule"] = {
							off = true,
						}
					}
				}
			}
		}
		]]

		-- confirm violations with no config
		lintTestHelper(assert, {
			content = customRuleContents,
			expectedExitCode = 1,
			customRuleContents = customRuleContents,
			disableDefaultLints = true,
			outputExpectations = { { expectedOutput = "customRule" } },
		})

		-- confirm file doesn't violate with disabled rule config
		lintTestHelper(assert, {
			content = customRuleContents,
			expectedExitCode = 0,
			customRuleContents = customRuleContents,
			disableDefaultLints = true,
			configContents = configContents,
			outputExpectations = { { expectedOutput = "customRule", count = 0 } },
		})
	end)

	suite:case("configuredRuleSeverityOverridesDefault", function(assert)
		local configContents = [[
return {
	lute = {
		lint = {
			ruleconfigs = {
				["divide_by_zero"] = {
					severity = "error"
				}
			}
		}
	}
}
]]

		lintTestHelper(assert, {
			content = "local _ = 1 / 0",
			expectedExitCode = 1,
			configContents = configContents,
			outputExpectations = {
				{ expectedOutput = "error[divide_by_zero]", count = 1 },
				{ expectedOutput = "warning[divide_by_zero]", count = 0 },
			},
		})
	end)

	suite:case("rulesGivenByConfigRulepathsAreLoadedInAdditionToCliPassedRulesAndRan", function(assert)
		local ruleTemplate = [[
return {
	name = %q,
	lint = function(cst, sourcepath, context)
		return {
			{
				lintname = %q,
				severity = "warn",
				message = %q,
				location = cst.location
			}
		}
	end
}
		]]
		-- Create the config-provided rules (loaded via config.rulepaths, NOT via -r)
		local configuredAbsoluteRulePath = path.format(path.join(tmpDir, "configuredAbsRule.luau"))
		fs.writeStringToFile(
			configuredAbsoluteRulePath,
			(ruleTemplate :: any):format(
				"configuredAbsoluteRule",
				"configuredAbsoluteRule",
				"configuredAbsoluteRule ran."
			)
		)
		local configuredRelativePath = path.format(path.join(tmpDir, "configuredRelativeRule.luau"))
		fs.writeStringToFile(
			configuredRelativePath,
			(ruleTemplate :: any):format(
				"configuredRelativeRule",
				"configuredRelativeRule",
				"configuredRelativeRule ran."
			)
		)

		-- The CLI-provided rule is passed via customRuleContents (which uses -r),
		-- while the config-provided rules are referenced via config.rulepaths
		lintTestHelper(assert, {
			content = "local x = 1",
			expectedExitCode = 1,
			customRuleContents = [[
return {
	name = "cliRule",
	lint = function(cst, sourcepath, context)
		return {
			{
				lintname = "cliRule",
				severity = "warn",
				message = "CLI Rule Ran.",
				location = cst.location
			}
		}
	end
}
]],
			configContents = ([[
return {
	lute = {
		lint = {
			rulepaths = { %q, "./configuredRelativeRule.luau" },
		}
	}
}
]]):format(configuredAbsoluteRulePath),
			disableDefaultLints = true,
			outputExpectations = {
				-- both config-given and CLI-given rules should have ran
				{ expectedOutput = "configuredAbsoluteRule ran.", count = 1 },
				{ expectedOutput = "configuredRelativeRule ran.", count = 1 },
				{ expectedOutput = "CLI Rule Ran.", count = 1 },
			},
			processOptions = {
				cwd = path.format(tmpDir),
			},
		})
	end)

	suite:case(
		"lute lint properly loads rule-specific configuration for rules provided by config.rulepaths",
		function(assert)
			local testSubDir = path.join(tmpDir, "module")
			fs.createDirectory(testSubDir)

			local configuredRulePath = path.join(testSubDir, "configuredRule.luau")
			local configuredRuleContents = [[
		return {
			name = "configuredRule",
			lint = function(cst, sourcepath, context)
				return {
					{
						lintname = "configuredRule",
						severity = "warn",
						message = `Configured Rule Ran with options.a = {context.options.a}`,
						location = cst.location,
						sourcepath = sourcepath,
					}
				}
			end
		}
		]]
			fs.writeStringToFile(configuredRulePath, configuredRuleContents)

			local configFile = path.join(testSubDir, ".config.luau")
			local configContents = ([[
		return {
			lute = {
				lint = {
					rulepaths = { %q },
					ruleconfigs = {
						["configuredRule"] = {
							ignores = { "**/ignoredDir/**" },
							options = {
								a = 1,
							}
						}
					}
				}
			}
		}
		]]):format(path.format(configuredRulePath))
			fs.writeStringToFile(configFile, configContents)

			local ignoredDir = path.join(testSubDir, "ignoredDir")
			local notIgnoredDir = path.join(testSubDir, "not_ignored")
			fs.createDirectory(ignoredDir)
			fs.createDirectory(notIgnoredDir)
			local ignoredFile = path.join(ignoredDir, "ignored.luau")
			local notIgnoredFile = path.join(notIgnoredDir, "valid.luau")
			local violatingContents = "print('hello world')"
			fs.writeStringToFile(ignoredFile, violatingContents)
			fs.writeStringToFile(notIgnoredFile, violatingContents)

			local result = runProcess({
				lutePath,
				"lint",
				"-c",
				path.format(configFile),
				path.format(testSubDir),
			})
			assert.eq(result.exitcode, 1) -- errors
			assert.strNotContains(result.stdout, "ignored.luau")
			assert.strContains(result.stdout, "valid.luau")
			assert.strContains(result.stdout, "Configured Rule Ran with options.a = 1") -- options are correctly passed through
		end
	)

	suite:case("emptyIfBlockBasic", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.empty_if_block,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.empty_if_block, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:1-2:4 ──
   │
 1 │ ╭ if true then
 2 │ │ end
   │ ╰────────────^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("emptyIfBlockWithNonEmptyBlock", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	print("hello")
end
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.empty_if_block,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.empty_if_block, count = 0 },
			},
		})
	end)

	suite:case("emptyIfBlockWithEmptyElse", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	print("hello")
else
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.empty_if_block,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.empty_if_block, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:1-4:4 ──
   │
 1 │ ╭ if true then
 2 │ │     print("hello")
 3 │ │ else
 4 │ │ end
   │ ╰──────────────────^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("emptyIfBlockWithEmptyElseifs", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	print("hello")
elseif true then
elseif false then
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.empty_if_block,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.empty_if_block, count = 1 },
				{
					expectedOutput = [[
violator.luau:1:1-5:4 ──
   │
 1 │ ╭ if true then
 2 │ │     print("hello")
 3 │ │ elseif true then
 4 │ │ elseif false then
 5 │ │ end
   │ ╰──────────────────^
   │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("emptyIfBlockWithCommentsCommentsCountFalse", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	-- This is a comment
end

if false then
	-- Another comment
	-- More comments
else
	-- Comment in else
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.empty_if_block,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.empty_if_block, count = 2 },
				{
					expectedOutput = [[
violator.luau:1:1-3:4 ──
   │
 1 │ ╭ if true then
 2 │ │     -- This is a comment
 3 │ │ end
   │ ╰────────────────────────^
   │
]],
					count = 1,
				},
				{
					expectedOutput = [[
violator.luau:5:1-10:4 ──
    │
 5  │ ╭ if false then
 6  │ │     -- Another comment
 7  │ │     -- More comments
 8  │ │ else
 9  │ │     -- Comment in else
 10 │ │ end
    │ ╰──────────────────────^
    │
]],
					count = 1,
				},
			},
		})
	end)

	suite:case("emptyIfBlockWithCommentsCommentsCountTrue", function(assert)
		local configContents = [[
return {
	lute = { lint = { ruleconfigs = {
		empty_if_block = {
			options = {
				comments_count = true,
			},
		},
	} } },
}
]]
		lintTestHelper(assert, {
			content = [[
if true then
	-- This is a comment
end

if false then
	-- comment
else
	-- Comment in else
end

if true then
	--comment
elseif true then
	-- Comment in elseif
elseif false then
	-- Comment in elseif
end
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.empty_if_block,
			disableDefaultLints = true,
			configContents = configContents,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.empty_if_block, count = 0 },
			},
		})
	end)

	suite:case("globalFunctionInScopeWarnsInsideIf", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	function foo()
	end
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.global_function_in_scope,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.global_function_in_scope, count = 1 },
			},
		})
	end)

	suite:case("globalFunctionInScopeWarnsInsideFunction", function(assert)
		lintTestHelper(assert, {
			content = [[
local function outer()
	function inner()
	end
end
]],
			expectedExitCode = 1,
			rulePath = defaultRulesPaths.global_function_in_scope,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.global_function_in_scope, count = 1 },
			},
		})
	end)

	suite:case("globalFunctionInScopeAllowsTopLevel", function(assert)
		lintTestHelper(assert, {
			content = [[
function foo()
end

function bar()
end
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.global_function_in_scope,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.global_function_in_scope, count = 0 },
			},
		})
	end)

	suite:case("globalFunctionInScopeAllowsLocalFunctionNested", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	local function foo()
	end
end
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.global_function_in_scope,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.global_function_in_scope, count = 0 },
			},
		})
	end)

	suite:case("globalFunctionInScopeAllowsTableMethods", function(assert)
		lintTestHelper(assert, {
			content = [[
if true then
	local t = {}
	function t:foo()
	end
	function t.bar()
	end
end
]],
			expectedExitCode = 0,
			rulePath = defaultRulesPaths.global_function_in_scope,
			disableDefaultLints = true,
			outputExpectations = {
				{ expectedOutput = LINT_RULE_MESSAGES.global_function_in_scope, count = 0 },
			},
		})
	end)

	suite:case("luteLintCurrentDirFindsLuauFiles", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local violatorPath = path.format(path.join(testSubDir, "violator.luau"))
		fs.writeStringToFile(violatorPath, "local x = 1 / 0")

		local result = runProcess({ lutePath, "lint" }, {
			cwd = path.format(testSubDir),
		})

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
	end)

	suite:case("luteLintCurrentDirFindsLuaFiles", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local violatorPath = path.format(path.join(testSubDir, "violator.lua"))
		fs.writeStringToFile(violatorPath, "local x = 1 / 0")

		local result = runProcess({ lutePath, "lint" }, {
			cwd = path.format(testSubDir),
		})

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
	end)

	suite:case("luteLintCurrentDirRecursive", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		local nestedDir = path.join(testSubDir, "nested")
		fs.createDirectory(testSubDir)
		fs.createDirectory(nestedDir)

		local violatorPath = path.format(path.join(nestedDir, "violator.luau"))
		fs.writeStringToFile(violatorPath, "local x = 1 / 0")

		local result = runProcess({ lutePath, "lint" }, {
			cwd = path.format(testSubDir),
		})

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
	end)

	suite:case("luteLintCurrentDirNoLuauFiles", function(assert)
		local testSubDir = path.join(tmpDir, "module")
		fs.createDirectory(testSubDir)

		local result = runProcess({ lutePath, "lint" }, {
			cwd = path.format(testSubDir),
		})

		assert.eq(result.exitcode, 0)
	end)

	suite:case("exactTextOutput", function(assert)
		local result = runProcess({
			lutePath,
			"lint",
			"-r",
			defaultRulesPaths.divide_by_zero,
			"--no-default-lints",
			"-s",
			"local x = 1 / 0",
		})

		assert.eq(result.exitcode, 1)
		assert.eq(
			result.stdout,
			"warning[divide_by_zero]: Division by zero detected.\n"
				.. "\n"
				.. "   ┌── input:1:11-16 ──\n"
				.. "   │\n"
				.. " 1 │ local x = 1 / 0\n"
				.. "   │           ^^^^^\n"
				.. "   │\n"
				.. "\n"
				.. "Suggested fix: math.huge\n"
				.. "\n"
				.. "For additional info: https://lute.luau.org/cli/lint/divide_by_zero.html\n"
				.. "\n"
		)
	end)

	suite:case("outputFlagWritesTextToFile", function(assert)
		local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
		local outputPath = path.format(path.join(tmpDir, "lint_output.txt"))
		fs.writeStringToFile(violatorPath, "local x = 1 / 0\n")

		local result = runProcess({
			lutePath,
			"lint",
			"-r",
			defaultRulesPaths.divide_by_zero,
			"--no-default-lints",
			"-o",
			outputPath,
			violatorPath,
		})

		assert.eq(result.exitcode, 1)
		assert.eq(fs.exists(outputPath), true)
		local outputContent = fs.readFileToString(outputPath)
		assert.strContains(outputContent, LINT_RULE_MESSAGES.divide_by_zero)
		assert.strNotContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
	end)

	suite:case("outputFlagWritesJsonToFile", function(assert)
		local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
		local outputPath = path.format(path.join(tmpDir, "lint_output.json"))
		fs.writeStringToFile(violatorPath, "local x = 1 / 0\n")

		local result = runProcess({
			lutePath,
			"lint",
			"-r",
			defaultRulesPaths.divide_by_zero,
			"--no-default-lints",
			"-j",
			"-o",
			outputPath,
			violatorPath,
		})

		assert.eq(result.exitcode, 0)
		assert.eq(fs.exists(outputPath), true)
		local outputContent = fs.readFileToString(outputPath)
		assert.never.throws(function()
			json.deserialize(outputContent)
		end)
		assert.strContains(outputContent, "divide_by_zero")
		assert.strContains(outputContent, '"items"')
		assert.strNotContains(result.stdout, "divide_by_zero")
	end)

	suite:case("outputFlagStringInputWritesToFile", function(assert)
		local outputPath = path.format(path.join(tmpDir, "lint_string_output.txt"))

		local result = runProcess({
			lutePath,
			"lint",
			"-r",
			defaultRulesPaths.divide_by_zero,
			"--no-default-lints",
			"-s",
			"local x = 1 / 0",
			"-o",
			outputPath,
		})

		assert.eq(result.exitcode, 1)
		assert.eq(fs.exists(outputPath), true)
		local outputContent = fs.readFileToString(outputPath)
		assert.strContains(outputContent, LINT_RULE_MESSAGES.divide_by_zero)
		assert.strNotContains(result.stdout, LINT_RULE_MESSAGES.divide_by_zero)
	end)

	suite:case("outputFlagStringInputJsonWritesToFile", function(assert)
		local outputPath = path.format(path.join(tmpDir, "lint_string_json_output.json"))

		local result = runProcess({
			lutePath,
			"lint",
			"-r",
			defaultRulesPaths.divide_by_zero,
			"--no-default-lints",
			"-s",
			"local x = 1 / 0",
			"-j",
			"-o",
			outputPath,
		})

		assert.eq(result.exitcode, 0)
		assert.eq(fs.exists(outputPath), true)
		local outputContent = fs.readFileToString(outputPath)
		assert.never.throws(function()
			json.deserialize(outputContent)
		end)
		assert.strContains(outputContent, "divide_by_zero")
		assert.strNotContains(result.stdout, "divide_by_zero")
	end)
end)
