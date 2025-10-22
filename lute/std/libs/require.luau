local fs = require("@lute/fs")
local luau = require("@std/luau")

local function requirebypath(path: string): any
	local migrationHandle = fs.open(path, "r")

	local migrationBytecode = luau.compile(fs.read(migrationHandle))

	fs.close(migrationHandle)

	return luau.load(migrationBytecode, path)()
end

return table.freeze({ requirebypath = requirebypath })
