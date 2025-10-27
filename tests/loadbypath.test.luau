local fs = require("@std/fs")
local luau = require("@std/luau")
local process = require("@std/process")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

-- local REQUIRER_CONTENTS = [[
-- local args = { ... }
-- assert(#args == 2, "Expected one argument: path to Luau script to require")
-- print(args[2])
-- ]]

local REQUIRER_CONTENTS = [[
local args = { ... }
assert(#args == 2, "Expected one argument: path to Luau script to require")

local fs = require("@std/fs")
print(if fs.exists(args[2]) then "Success" else "Failure")

-- local luau = require("@std/luau")
-- local result = luau.loadbypath(args[2])
-- print(result)
]]

local REQUIREE_CONTENTS = [[return "Success"]]

local lutePath = process.execpath()
local tmpDir = system.tmpdir()

test.suite("Lute CLI", function(suite)
	suite:case("help1", function(check)
		-- Setup
		-- Create files
		local requirerPath = path.join(tmpDir, "requirer.luau")
		local requirerFile = fs.open(requirerPath, "w+")
		fs.write(requirerFile, REQUIRER_CONTENTS)
		fs.close(requirerFile)

		local requireePath = path.join(tmpDir, "requiree.luau")
		local requireeFile = fs.open(requireePath, "w+")
		fs.write(requireeFile, REQUIREE_CONTENTS)
		fs.close(requireeFile)

		local lutePathStr = path.format(lutePath)
		print(`Lute path: {lutePathStr}`)
		print(`cwd: {process.cwd()}`)

		for _, f in fs.listdir(tmpDir) do
			print(`tmp dir entry: {f.name}`)
		end

		local result = luau.loadbypath(requireePath)
		check.eq(result, "Success")

		local result = process.run({ lutePathStr, path.format(requirerPath), path.format(requireePath) })
		check.eq(result.stdout, "Success\n")
		check.eq(result.exitcode, 0)

		-- Cleanup
		fs.remove(requirerPath)
		fs.remove(requireePath)
	end)
end)

test.run()
