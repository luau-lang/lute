local fs = require("@std/fs")
local path = require("@std/path")

local binary = require("./binary")
local configs = require("./configs")
local paths = require("./paths")
local release = require("./release")

local REPO = "luau-lang/lute"

local function parseLuteVersion(rawConfig: { [any]: any }): string?
	local lute = rawConfig.lute
	if lute == nil then
		return nil
	end
	if typeof(lute) ~= "table" then
		error("`.config.luau` field `lute` must be a table")
	end

	local toolchain = lute.toolchain
	if toolchain == nil then
		return nil
	end
	if typeof(toolchain) ~= "table" then
		error("`.config.luau` field `lute.toolchain` must be a table")
	end

	local pinned = toolchain.lute
	if pinned == nil then
		return nil
	end
	if typeof(pinned) ~= "string" then
		error(`\`.config.luau\` field \`lute.toolchain.lute\` must be a string`)
	end
	return pinned
end

local function ensureInstalled(tag: string): string
	tag = release.normalizeTag(tag)
	local destination = path.format(path.join(paths.versionsPath(), "lute", tag, paths.exeName()))
	if fs.exists(destination) then
		return destination
	end

	fs.createDirectory(path.dirname(destination), { makeParents = true })
	local bytes = release.downloadBinary(REPO, tag, paths.exeName())
	binary.installBinary(bytes, destination)
	return destination
end

local function resolvePinnedLute(): string?
	for _, rawConfig in configs.walkConfigPaths() do
		local pinned = parseLuteVersion(rawConfig)
		if pinned ~= nil then
			return ensureInstalled(pinned)
		end
	end
	return nil
end

return table.freeze({
	resolvePinnedLute = resolvePinnedLute,
})
