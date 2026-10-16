local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local function lutePath(): string
	return path.format(path.join(process.homedir(), ".lute"))
end

local function binPath(): string
	return path.format(path.join(lutePath(), "bin"))
end

local function exeName(): string
	return if system.win32 then "lute.exe" else "lute"
end

local function exePath(): string
	return path.format(path.join(binPath(), exeName()))
end

return table.freeze({
	lutePath = lutePath,
	binPath = binPath,
	exeName = exeName,
	exePath = exePath,
})
