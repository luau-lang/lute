local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execpath())
local tmpDir = system.tmpdir()
local rulesDir = path.format(path.join(".", "lints"))
local almostSwappedExample = path.format(path.join("examples", "lints", "almost_swapped.luau"))
local divideByZeroExample = path.format(path.join("examples", "lints", "divide_by_zero.luau"))

local USAGE = "Usage: lute lint [OPTIONS] [...PATHS]"

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
		assert.neq(result.stdout:find(USAGE, 1, true), nil)

		result = process.run({ lutePath, "lint", "--h" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find(USAGE, 1, true), nil)

		result = process.run({ lutePath, "lint", "--help" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find(USAGE, 1, true), nil)
	end)

	suite:case("lute lint no rule", function(assert)
		local result = process.run({ lutePath, "lint" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Error: No lint rules specified.", 1, true), nil)
	end)

	suite:case("lute lint no input file", function(assert)
		local result = process.run({ lutePath, "lint", "-r", "a_rule.luau" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Error: No input files specified.", 1, true), nil)
	end)

	suite:case("divide_by_zero", function(assert)
		-- Setup
		-- Create a file that violates the rule
		local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
		fs.writestringtofile(
			violatorPath,
			[[
local x = 1 / 0
    ]]
		)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "lint", "-r", divideByZeroExample, violatorPath })

		-- Check
		assert.eq(result.exitcode, 0)

		assert.neq(result.stdout:find("warning[divide_by_zero]: Division by zero detected.", 1, true), nil)
		local expected = [[
violator.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		-- Teardown
		fs.remove(violatorPath)
	end)

	suite:case("almost_swapped", function(assert)
		-- Setup
		-- Create a file that violates the rule
		local violatorPath = path.format(path.join(tmpDir, "violator.luau"))
		fs.writestringtofile(
			violatorPath,
			[[
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
    ]]
		)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "lint", "-r", almostSwappedExample, violatorPath })

		-- Check
		assert.eq(result.exitcode, 0)
		-- We expect 4 warnings, so stdout should be split into 5 parts
		assert.eq(#result.stdout:split("warning[almost_swapped]: This looks like a failed attempt to swap."), 5)
		local expected = [[
violator.luau:1:1-2:6 ──
   │
 1 │ ╭ a = b
 2 │ │ b = a
   │ ╰─────^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		expected = [[
violator.luau:6:1-7:6 ──
   │
 6 │ ╭ x = y
 7 │ │ y = x
   │ ╰─────^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		expected = [[
violator.luau:10:1-11:10 ──
    │
 10 │ ╭ t.a = t.b
 11 │ │ t.b = t.a
    │ ╰─────────^
    │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		expected = [[
violator.luau:14:2-15:17 ──
    │
 14 │ ╭ 	t["a"] = t["b"]
 15 │ │ 	t["b"] = t["a"]
    │ ╰────────────────^
    │
]] -- todo: address tab shenanigans
		assert.neq(result.stdout:find(expected, 1, true), nil)

		-- Teardown
		fs.remove(violatorPath)
	end)

	suite:case("lute lint multiple rules", function(assert)
		-- Setup
		fs.createdirectory(rulesDir)
		-- Copy almostSwapped.luau to rulesDir/almostSwapped.luau
		fs.copy(almostSwappedExample, path.join(rulesDir, "almost_swapped.luau"))
		-- Copy divide_by_zero to rulesDir/divide_by_zero/init.luau
		local divideByZeroDir = path.join(rulesDir, "divide_by_zero")
		fs.createdirectory(divideByZeroDir)
		fs.copy(divideByZeroExample, path.join(divideByZeroDir, "init.luau"))
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
		assert.eq(result.exitcode, 0)

		assert.neq(result.stdout:find("warning[divide_by_zero]: Division by zero detected.", 1, true), nil)
		local expected = [[
violator.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		assert.neq(
			result.stdout:find("warning[almost_swapped]: This looks like a failed attempt to swap.", 1, true),
			nil
		)
		expected = [[
violator.luau:3:1-4:6 ──
   │
 3 │ ╭ a = b
 4 │ │ b = a
   │ ╰─────^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

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
		local result = process.run({ lutePath, "lint", "-r", "examples/lints", violatorPath1, path.format(modulePath) })

		-- Check
		assert.eq(result.exitcode, 0)

		assert.eq(#result.stdout:split("warning[divide_by_zero]: Division by zero detected."), 3)
		local expected = [[
violator1.luau:1:11-16 ──
   │
 1 │ local x = 1 / 0
   │           ^^^^^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		expected = [[
violator2.lua:1:11-17 ──
   │
 1 │ local y = 10 / 0
   │           ^^^^^^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		assert.eq(#result.stdout:split("warning[almost_swapped]: This looks like a failed attempt to swap."), 3)
		expected = [[
violator1.luau:3:1-4:6 ──
   │
 3 │ ╭ a = b
 4 │ │ b = a
   │ ╰─────^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		expected = [[
violator2.lua:5:1-6:6 ──
   │
 5 │ ╭ x = y
 6 │ │ y = x
   │ ╰─────^
   │
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)
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
		assert.eq(result.exitcode, 0)

		local expected = [[
lintee.luau': @std/syntax/parser.luau:12: parsing failed:
(0, 0) - (0, 5): Incomplete statement: expected assignment or a function call
]]
		assert.neq(result.stdout:find(expected, 1, true), nil)

		assert.neq(result.stdout:find("warning[divide_by_zero]: Division by zero detected.", 1, true), nil)
		assert.neq(
			result.stdout:find("warning[almost_swapped]: This looks like a failed attempt to swap.", 1, true),
			nil
		)

		-- Teardown
		fs.remove(lintee)
		fs.remove(violatorPath)
	end)
end)

test.run()
