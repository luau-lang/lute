local fs_utils = require("../utils/fs_utils")
local net = require("@std/net")
local unzip = require("../../extern/unzip")

export type git = {
	installZipArchive: (self: git, name: string, version: string, content: string) -> (),
	downloadFromGitHubArchive: (self: git, url: string, token: string?) -> string,
}

local Git = {} :: git

local function sanitizePath(path: string): string
	-- Input validation
	if not path or type(path) ~= "string" then
		error("Path must be a string")
	end

	if #path == 0 then
		error("Path cannot be empty")
	end

	local MAX_PATH_LENGTH = 255
	if #path > MAX_PATH_LENGTH then
		error("Path too long (max " .. MAX_PATH_LENGTH .. " characters)")
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

function Git:installZipArchive(name: string, version: string, content: string)
	local reader = unzip.load(buffer.fromstring(content))

	reader:walk(function(entry, depth)
		if entry.isDirectory then
			return
		end

		local content = reader:extract(entry, { type = "text" }) :: string

		local sanitized = sanitizePath(entry.name)
		local slash = string.find(sanitized, "/")
		assert(slash, `Expected entry name to contain a slash: {sanitized}`)

		local output_path = `Packages/{name}/{string.sub(sanitized, slash)}`
		fs_utils.writestringtofile(output_path, content)
	end)
end

function Git:downloadFromGitHubArchive(url: string): string
	local headers = {}

	-- TODO: support token authentication.
	-- local token = nil
	-- if token ~= nil and token ~= "" then
	-- 	headers["Authorization"] = `Bearer {token}`
	-- end

	local response = net.request(url, { method = "GET", headers = headers })
	local body = response.body
	return body
end

return Git
