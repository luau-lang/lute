local fs = require("@lute/fs")
local luau = require("@std/luau")
local path = require("@std/path")

local function requirebypath(requirePath: path.pathlike): any
	local requirePathStr = if typeof(requirePath) == "string" then requirePath else path.format(requirePath)

	local migrationHandle = fs.open(requirePathStr, "r")

	local migrationBytecode = luau.compile(fs.read(migrationHandle))

	fs.close(migrationHandle)

	return luau.load(migrationBytecode, requirePathStr)()
end

return table.freeze({ requirebypath = requirebypath })
