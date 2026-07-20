local fs = require("@std/fs")
local path = require("@std/path")

local binary = require("./binary")
local config = require("./config")
local paths = require("./paths")
local release = require("./release")

local function ensureInstalled(repo: string, tag: string, toolName: string): string
	tag = release.normalizeTag(tag)
	local destination = paths.installationPath(toolName, tag)
	if fs.exists(destination) then
		return destination
	end

	fs.createDirectory(path.dirname(destination), { makeParents = true })
	print(`Installing {toolName} {tag}...`)
	local bytes = release.downloadBinary(repo, tag, paths.exeName(toolName))
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

	local toolchain = (lute :: { [any]: any }).toolchain
	if toolchain == nil then
		return nil
	end
	if typeof(toolchain) ~= "table" then
		error("`.config.luau` field `lute.toolchain` must be a table")
	end

	local pinned = (toolchain :: { [any]: any })[tool]
	if pinned == nil then
		return nil
	end
	if typeof(pinned) ~= "string" then
		error(`\`.config.luau\` field \`lute.toolchain.{tool}\` must be a string`)
	end
	return pinned :: string
end

local function resolvePinnedTool(repo: string, tool: string): string?
	for rawConfig in config.walkConfigPaths() do
		local pinned = parseToolVersion(rawConfig, tool)
		if pinned ~= nil then
			return ensureInstalled(repo, pinned, tool)
		end
	end
	return nil
end

return table.freeze({
	resolvePinnedTool = resolvePinnedTool,
})
