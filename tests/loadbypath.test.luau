local fs = require("@lute/fs")
local process = require("@lute/process")
local path = require("@std/path")
local system = require("@std/system")
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
local tmpDir = system.tmpdir()

test.suite("Lute CLI", function(suite)
	suite:case("help1", function(check)
		-- Setup
		-- Create files
		local requirerPath = path.format(path.join(tmpDir, "requirer.luau"))
		local requirerFile = fs.open(requirerPath, "w+")
		fs.write(requirerFile, REQUIRER_CONTENTS)
		fs.close(requirerFile)

		local requireePath = path.format(path.join(tmpDir, "requiree.luau"))
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
end)

test.run()
