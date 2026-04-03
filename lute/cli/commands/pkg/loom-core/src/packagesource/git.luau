local authenticationStore = require("../authentication/authenticationstore")
local fsUtils = require("../utils/fsutils")
local net = require("@std/net")
local process = require("@std/process")
local unzip = require("../../extern/unzip")

export type Git = {
	installZipArchive: (self: Git, name: string, version: string, content: string) -> (),
	downloadFromGitHubArchive: (self: Git, url: string) -> string,
}

local Git = {} :: Git

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

	-- Security checks - prevent directory traversal
	if path:match("%.%.") then
		error("Path contains '..' (directory traversal attempt)")
	end

	-- Remove/reject dangerous characters
	if path:match("[\0\r\n]") then
		error("Path contains invalid control characters")
	end

	-- Normalize path separators and remove redundant slashes
	local normalized = path:gsub("\\", "/"):gsub("//+", "/")

	-- Remove leading slashes but preserve trailing slash for directories
	normalized = normalized:gsub("^/+", "")

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

function Git:installZipArchive(name: string, _version: string, content: string)
	local reader = unzip.load(buffer.fromstring(content))

	reader:walk(function(entry, _depth)
		if entry.isDirectory then
			return
		end

		local content = reader:extract(entry, { type = "text" }) :: string

		local sanitized = sanitizePath(entry.name)
		local slash = string.find(sanitized, "/")
		assert(slash, `Expected entry name to contain a slash: {sanitized}`)

		local outputPath = `Packages/{name}/{string.sub(sanitized, slash)}`
		fsUtils.writestringtofile(outputPath, content)
	end)
end

function Git:downloadFromGitHubArchive(url: string): string
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

return Git
