local authenticationStore = require("./authenticationstore")
local fs = require("@std/fs")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local projectmanifest = require("./projectmanifest")
local system = require("@std/system")
local unzip = require("../extern/unzip")

local function sanitizePath(path: string): string
	-- Input validation
	if not path or type(path) ~= "string" then
		error("Path must be a string")
	end

	if #path == 0 then
		error("Path cannot be empty")
	end

	local maxPathLength = 255
	if #path > maxPathLength then
		error("Path too long (max " .. maxPathLength .. " characters)")
	end

	-- Remove/reject dangerous characters
	if path:match("[\0\r\n]") then
		error("Path contains invalid control characters")
	end

	-- Normalize path separators and remove redundant slashes
	local normalized = path:gsub("\\", "/"):gsub("//+", "/")

	-- Remove leading slashes but preserve trailing slash for directories
	normalized = normalized:gsub("^/+", "")

	-- Security check - prevent directory traversal via ".." path components
	if normalized == ".." or normalized:match("^%.%./") or normalized:match("/%.%./") or normalized:match("/%.%.$") then
		error("Path contains '..' (directory traversal attempt)")
	end

	return normalized
end

local function getGithubAuthenticationToken(): string?
	local githubToken = process.env.GITHUB_TOKEN
	if githubToken ~= nil then
		return githubToken
	end

	local store = authenticationStore.loadAuthenticationStore()
	local entry = store["github.com"]
	if entry ~= nil then
		return entry.token
	end

	return nil
end

local function installZipArchive(content: string, installPath: string)
	local reader = unzip.load(buffer.fromstring(content))

	reader:walk(function(entry, _depth)
		if entry.isDirectory then
			return
		end

		local content = reader:extract(entry, { type = "text" }) :: string

		local sanitized = sanitizePath(entry.name)
		local slash = string.find(sanitized, "/")
		assert(slash, `Expected entry name to contain a slash: {sanitized}`)

		local outputPath = `{installPath}/{string.sub(sanitized, slash)}`
		fs.createDirectory(path.dirname(outputPath), { makeParents = true })
		fs.writeStringToFile(outputPath, content)
	end)
end

local function downloadFromGitHubArchive(url: string): string
	local headers = {}

	local token = getGithubAuthenticationToken()
	if token ~= nil and token ~= "" then
		headers["Authorization"] = `Bearer {token}`
	end

	local response = net.request(url, { method = "GET", headers = headers })
	if not response.ok then
		error(`Failed to download {url}: HTTP {response.status}\n{string.sub(response.body, 1, 200)}`)
	end
	return response.body
end

local function installPackage(pkg: projectmanifest.DependencySpec, installPath: string): ()
	local url = `{pkg.source}/archive/{pkg.rev}.zip`
	local zipArchive = downloadFromGitHubArchive(url)
	installZipArchive(zipArchive, installPath)
end

local function installRelease(pkg: projectmanifest.DependencySpec, installPath: string): ()
	local url = `{pkg.source}/releases/download/{pkg.rev}/{pkg.name}-{system.os}-{system.arch}.zip`
	local zipArchive = downloadFromGitHubArchive(url)
	installZipArchive(zipArchive, installPath)
end

return {
	installPackage = installPackage,
	installRelease = installRelease,
}
