local config = require("../lib/config")
local release = require("../lib/release")

local REPO = "luau-lang/lute"

local function parseToolchainVersion(rawConfig: { [any]: any }, tool: string): string?
	if typeof(rawConfig.lute) ~= "table" then
		return nil
	end
	if typeof(rawConfig.lute.toolchain) ~= "table" then
		return nil
	end
	local pinned = (rawConfig.lute.toolchain :: any)[tool]
	if pinned == nil then
		return nil
	end
	if typeof(pinned) ~= "string" then
		error(`lute.toolchain.{tool} must be a string`)
	end
	return pinned
end

local function resolveLuteVersion(): string?
	for rawConfig in config.walkConfigPaths() do
		local pinned = parseToolchainVersion(rawConfig, "lute")
		if pinned ~= nil then
			return release.ensureInstalled(REPO, pinned, "lute")
		end
	end
	return nil
end

return resolveLuteVersion()
