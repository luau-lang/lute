local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execpath())
local tmpDir = system.tmpdir()

test.suite("lute lint", function(suite)
	suite:case("lute lint help message", function(assert)
		local result = process.run({ lutePath, "lint", "-h" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Usage: lute lint [OPTIONS] [RULE] [PATH]", 1, true), nil)

		result = process.run({ lutePath, "lint", "--h" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Usage: lute lint [OPTIONS] [RULE] [PATH]", 1, true), nil)

		result = process.run({ lutePath, "lint", "--help" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Usage: lute lint [OPTIONS] [RULE] [PATH]", 1, true), nil)
	end)

	suite:case("lute lint no rule", function(assert)
		local result = process.run({ lutePath, "lint" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Error: No lint rule specified.", 1, true), nil)
	end)

	suite:case("lute lint no rule", function(assert)
		local result = process.run({ lutePath, "lint", "a_rule" })

		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Error: No input file specified.", 1, true), nil)
	end)

	suite:case("divide_by_zero", function(assert)
		-- Setup
		local rule = path.format(path.join("examples", "lints", "divide_by_zero.luau"))

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
		local result = process.run({ lutePath, "lint", rule, violatorPath })

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
		local rule = path.format(path.join("examples", "lints", "almost_swapped.luau"))

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
		local result = process.run({ lutePath, "lint", rule, violatorPath })

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
end)

test.run()
