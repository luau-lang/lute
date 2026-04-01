local fs = require("@std/fs")
local process = require("@std/process")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local REQUIRER_CONTENTS = [[
local args = { ... }
assert(#args == 2, "Expected one argument: path to Luau script to require")

local luau = require("@std/luau")
local result = luau.loadModule(args[2])
print(result)
]]

local REQUIREE_CONTENTS = [[return "Success"]]

local lutePath = process.execPath()

local tmpDirStr = system.tmpdir()
local testDir = path.join(tmpDirStr, "lute_require_test")
local testDirStr = path.format(testDir)

test.suite("LuteCliRun", function(suite)
	suite:beforeall(function()
		if not fs.exists(testDirStr) then
			fs.createDirectory(testDirStr)
		end
	end)

	suite:case("loadModule", function(check)
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

		local result = process.run({ tostring(lutePath), requirerPath, requireePath })
		check.eq(result.exitcode, 0)
		check.eq(result.stdout, "Success\n")

		-- Cleanup
		fs.remove(requirerPath)
		fs.remove(requireePath)
	end)

	suite:afterall(function()
		if fs.exists(testDirStr) then
			fs.removeDirectory(testDirStr)
		end
	end)
end)
