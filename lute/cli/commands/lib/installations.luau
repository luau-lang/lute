local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

local binary = require("./binary")
local paths = require("./paths")
local release = require("./release")

local function ensureInstalled(tool: string, tag: string, repo: string): string
	tag = release.normalizeTag(tag)
	local destination = paths.installationPath(tool, tag)
	if fs.exists(destination) then
		return destination
	end

	fs.createDirectory(path.dirname(destination), { makeParents = true })
	print(`Installing {tool} {tag}...`)
	local bytes = release.downloadBinary(repo, tag, paths.exeName(tool))
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

local function walkConfigPaths(startDir: string?): () -> { [any]: any }
    local current = path.format(path.normalize(startDir or process.cwd()))

    return function(): { [any]: any }
        while current do
            local candidate = path.format(path.join(current, ".config.luau"))

            local parent = path.format(path.dirname(current))
            if parent == current then
                current = nil
            else
                current = parent
            end

            if fs.exists(candidate) then
				local root = luau.loadModule(candidate)
				if typeof(root) ~= "table" then
					error(`{candidate} must return a table`)
				end
                return root
            end
        end
        
        return nil :: any
    end
end

local function resolvePinnedTool(tool: string, repo: string): string?
	for rawConfig in walkConfigPaths() do
		local pinned = parseToolVersion(rawConfig, tool)
		if pinned ~= nil then
			return ensureInstalled(tool, pinned, repo)
		end
	end
	return nil
end

return table.freeze({
	resolvePinnedTool = resolvePinnedTool,
})
