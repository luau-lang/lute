local fs = require("@std/fs")
local process = require("@std/process")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local COMPILER_CONTENTS = [[
local luau = require("@lute/luau")
local fs = require("@std/fs")

local args = { ... }
assert(#args == 2, "Expected one argument: path to Luau script to compile")

local handle = fs.open(args[2], "r")
local contents = fs.read(handle)
fs.close(handle)
luau.compile(contents)
print(`SUCCESS`)
]]

local COMPILEE_CONTENTS = [[return "Hello world"]]

local lutePath = process.execpath()
local tmpDir = system.tmpdir()

test.suite("LuteCliCompile", function(suite)
	suite:case("runCompile", function(check)
		-- Setup
		-- Create files
		local compilerPath = path.join(tmpDir, "compiler.luau")
		local compilerFile = fs.open(compilerPath, "w+")
		fs.write(compilerFile, COMPILER_CONTENTS)
		fs.close(compilerFile)

		local compileePath = path.join(tmpDir, "compilee.luau")
		local compileeFile = fs.open(compileePath, "w+")
		fs.write(compileeFile, COMPILEE_CONTENTS)
		fs.close(compileeFile)

		local result = process.run({ path.format(lutePath), path.format(compilerPath), path.format(compileePath) })
		-- Compilation should work with no memory leaks
		check.eq(result.stderr, "")
		check.eq(result.stdout, "SUCCESS\n")
		check.eq(result.exitcode, 0)

		-- -- Cleanup
		fs.remove(compilerPath)
		fs.remove(compileePath)
	end)
end)
