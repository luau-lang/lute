local fs = require("@std/fs")
local path = require("@std/path")

local binary = require("./binary")
local configs = require("./configs")
local paths = require("./paths")
local release = require("./release")

local function ensureInstalled(tool: string, tag: string): string
	tag = release.normalizeTag(tag)
	local destination = path.format(path.join(paths.versionsPath(), tool, tag, paths.exeName(tool)))
	if fs.exists(destination) then
		return destination
	end

	fs.createDirectory(path.dirname(destination), { makeParents = true })
	print(`Installing {tool} {tag}...`)
	local bytes = release.downloadBinary("luau-lang/lute", tag, paths.exeName(tool))
	binary.installBinary(bytes, destination)
	return destination
end

local function parseToolVersion(rawConfig: { [any]: any }, tool: string): string?
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

	local pinned = toolchain[tool]
	if pinned == nil then
		return nil
	end
	if typeof(pinned) ~= "string" then
		error(`\`.config.luau\` field \`lute.toolchain.{tool}\` must be a string`)
	end
	return pinned
end

local function resolvePinnedTool(tool: string): string?
	for _, rawConfig in configs.walkConfigPaths() do
		local pinned = parseToolVersion(rawConfig, tool)
		if pinned ~= nil then
			return ensureInstalled(tool, pinned)
		end
	end
	return nil
end

return table.freeze({
	resolvePinnedTool = resolvePinnedTool,
})
