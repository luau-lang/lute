local authenticationStore = require("./authenticationstore")
local credentialProvider = require("@commands/lib/credentials")
local fs = require("@std/fs")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local unzip = require("./unzip")

local function sanitizePath(path: string): string
	-- Input validation
	if not path or typeof(path) ~= "string" then
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

local function getGithubAuthenticationToken(repositoryPath: string): string?
	local githubToken = process.env.GITHUB_TOKEN
	if githubToken ~= nil and githubToken ~= "" then
		return githubToken
	end

	local providedToken = credentialProvider.resolveToken({
		protocol = "https",
		host = "github.com",
		path = repositoryPath,
	})
	if providedToken ~= nil and providedToken ~= "" then
		return providedToken
	end

	local store = authenticationStore.loadAuthenticationStore()
	local entry = store["github.com"]
	if typeof(entry) == "table" and typeof(entry.token) == "string" and entry.token ~= "" then
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

local function downloadFromGitHub(url: string, token: string?): string
	local headers = {
		["User-Agent"] = "lute-pkg",
	}

	if token ~= nil and token ~= "" then
		headers["Authorization"] = `Bearer {token}`
	end

	local response = net.request(url, { method = "GET", headers = headers })
	if not response.ok then
		error(`Failed to download {url}: HTTP {response.status}\n{string.sub(response.body, 1, 200)}`)
	end
	return response.body
end

local function installPackage(source: string, rev: string, installPath: string): ()
	local owner, repo = string.match(source, "^https?://github%.com/([^/]+)/([^/]+)")
	if not owner or not repo then
		error(`Unsupported GitHub source URL: {source}`)
	end

	local repositoryPath = `{owner}/{repo}`
	local url = `https://api.github.com/repos/{repositoryPath}/zipball/{rev}`

	local token = getGithubAuthenticationToken(repositoryPath)
	local zipArchive = downloadFromGitHub(url, token)

	local safeName = rev:gsub("[^%w%-_.]", "-")
	local tempDir = path.format(path.join(system.tmpdir(), `lute-pkg-install-{safeName}`))

	if fs.exists(tempDir) then
		fs.removeDirectory(tempDir, { recursive = true })
	end

	xpcall(installZipArchive, function(err)
		if fs.exists(tempDir) then
			fs.removeDirectory(tempDir, { recursive = true })
		end

		error(err, 0)
	end, zipArchive, tempDir)

	fs.move(tempDir, installPath)
end

return {
	installPackage = installPackage,
}
