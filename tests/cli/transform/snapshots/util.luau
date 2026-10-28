local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local MIGRATION_PATH = "./tests/cli/transform/snapshots/mutable_migration.luau"

local util = {}

--- Runs `lute transform` with `flags` on a temporary copy of `{inputName}.in`, then prints the exit code and the
--- resulting file contents. A copy is used so the fixture itself is never rewritten.
function util.printTransform(testName: string, inputName: string, flags: { string })
	local inFile = `./tests/cli/transform/snapshots/{inputName}.in`
	local tmpPath = path.format(path.join(system.tmpdir(), `lute_transform_snap_{testName}.luau`))
	fs.writeStringToFile(tmpPath, fs.readFileToString(inFile))

	local args = { path.format(process.execPath()), "transform" }
	for _, flag in flags do
		table.insert(args, flag)
	end
	table.insert(args, MIGRATION_PATH)
	table.insert(args, tmpPath)

	local result = process.run(args)
	local output = fs.readFileToString(tmpPath)
	fs.remove(tmpPath)

	print(`exit code: {result.exitcode}`)
	print(output)
end

return util
