local fs = require("@lute/fs")
local process = require("@lute/process")
local path = require("@std/path")
local test = require("@std/test")

local REQUIRER_CONTENTS = [[
local args = { ... }
assert(#args == 2, "Expected one argument: path to Luau script to require")

local luau = require("@std/luau")
local result = luau.loadbypath(args[2])
print(result)
]]

local REQUIREE_CONTENTS = [[return "Success"]]

local lutePath = process.execpath()

local tmpDirStr = ".tmp"
local tmpDirExists = fs.exists(tmpDirStr)
local testDir = path.join(tmpDirStr, "lute_require_test")
local testDirStr = path.format(testDir)

test.suite("Lute CLI", function(suite)
	suite:beforeall(function()
		if not tmpDirExists then
			fs.mkdir(tmpDirStr)
		end

		if not fs.exists(testDirStr) then
			fs.mkdir(testDirStr)
		end
	end)

	suite:case("help1", function(check)
		-- Setup
		-- Create files
		local requirerPath = path.format(path.join(testDir, "requirer.luau"))
		local requirerFile = fs.open(requirerPath, "w+")
		fs.write(requirerFile, REQUIRER_CONTENTS)
		fs.close(requirerFile)

		local requireePath = path.format(path.join(testDir, "requiree.luau"))
		local requireeFile = fs.open(requireePath, "w+")
		fs.write(requireeFile, REQUIREE_CONTENTS)
		fs.close(requireeFile)

		print(`Lute path: ${lutePath}`)
		print(`cwd: ${process.cwd()}`)

		local result = process.run({ lutePath, requirerPath, requireePath })
		check.eq(result.exitcode, 0)
		check.eq(result.stdout, "Success\n")

		-- Cleanup
		fs.remove(requirerPath)
		fs.remove(requireePath)
	end)

	suite:afterall(function()
		if fs.exists(testDirStr) then
			fs.rmdir(testDirStr)
		end

		if not tmpDirExists then
			fs.rmdir(tmpDirStr)
		end
	end)
end)

test.run()
