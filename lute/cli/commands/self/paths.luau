local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local function lutePath(): string
	return path.format(path.join(process.homedir(), ".lute"))
end

local function binPath(): string
	return path.format(path.join(lutePath(), "bin"))
end

local function exeName(tool: string): string
	return if system.win32 then `{tool}.exe` else tool
end

local function exePath(tool: string): string
	return path.format(path.join(binPath(), exeName(tool)))
end

local function versionsPath(): string
	return path.format(path.join(lutePath(), "versions"))
end

local function installationPath(tool: string, tag: string): string
	return path.format(path.join(versionsPath(), tool, tag, exeName(tool)))
end

return table.freeze({
	lutePath = lutePath,
	binPath = binPath,
	exeName = exeName,
	exePath = exePath,
	installationPath = installationPath,
})
