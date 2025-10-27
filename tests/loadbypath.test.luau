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
local luau = require("@std/luau")
local fs = require("@std/fs")

local args = { ... }
assert(#args == 2, "Expected one argument: path to Luau script to require")

local handle = fs.open(args[2], "r")
print("opened file handle")
local contents = fs.read(handle)
print("read file contents")
fs.close(handle)
print("closed file handle")
luau.compile(contents)
print(`SUCCESS`)
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

		local result = process.run({ lutePathStr, path.format(requirerPath), path.format(requireePath) })
		print(`process stderr: {result.stderr}`)
		print(`process result: {result.stdout}`)
		check.neq(result.stdout:find("SUCCESS"), nil)
		check.eq(result.exitcode, 0)

		-- -- Cleanup
		fs.remove(requirerPath)
		fs.remove(requireePath)
	end)
end)

test.run()
