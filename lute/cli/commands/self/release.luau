local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")
local system = require("@std/system")
local unzip = require("../pkg/loom-core/extern/unzip")

local function normalizeTag(tag: string): string
	local trimmed = stringext.trim(tag)
	if trimmed == "" then
		error("Release version cannot be empty")
	end
	local stripped = if string.match(trimmed, "^[vV]") then string.sub(trimmed, 2) else trimmed
	return `v{string.lower(stripped)}`
end

local function isNightlyTag(tag: string): boolean
	return string.find(normalizeTag(tag), "-nightly.", 1, true) ~= nil
end

type ReleaseInfo = {
	read tag_name: string?,
	read draft: boolean?,
}

local function selectLatestNightlyTag(releases: { ReleaseInfo }): string?
	for _, release in releases do
		if release.draft == true then
			continue
		end
		local tag = release.tag_name
		if tag ~= nil and isNightlyTag(tag) then
			return normalizeTag(tag)
		end
	end
	return nil
end

local function headers(): { [string]: string }
	local h = {
		["User-Agent"] = "lute-self",
		["Accept"] = "application/vnd.github+json",
	}
	local token = process.env.GITHUB_TOKEN
	if token ~= nil and token ~= "" then
		h["Authorization"] = `Bearer {token}`
	end
	return h
end

local function queryLatestTag(repo: string): string
	local url = `https://api.github.com/repos/{repo}/releases/latest`
	local res = net.request(url, { method = "GET", headers = headers() })
	if not res.ok then
		error(`Failed to query latest release: HTTP {res.status}\n{string.sub(res.body, 1, 200)}`)
	end
	local data = json.deserialize(res.body) :: { tag_name: string? }
	if data.tag_name == nil then
		error("Latest GitHub release did not include a tag")
	end
	return normalizeTag(data.tag_name)
end

local function queryLatestNightlyTag(repo: string): string
	for page = 1, 2 do
		local url = `https://api.github.com/repos/{repo}/releases?per_page=100&page={page}`
		local res = net.request(url, { method = "GET", headers = headers() })
		if not res.ok then
			error(`Failed to query nightly releases: HTTP {res.status}\n{string.sub(res.body, 1, 200)}`)
		end
		local data = json.deserialize(res.body) :: { ReleaseInfo }
		if #data == 0 then
			break
		end
		local tag = selectLatestNightlyTag(data)
		if tag ~= nil then
			return tag
		end
	end
	error("No nightly GitHub release found")
end

local function osSlug(): string
	if system.win32 then
		return "windows"
	elseif system.macos then
		return "macos"
	elseif system.linux then
		return "linux"
	else
		error(`Unsupported operating system: {system.os}`)
	end
end

local function archSlug(): string
	if system.arch == "x86_64" or system.arch == "amd64" or system.arch == "x64" then
		if system.macos then
			error("Lute releases do not currently support Intel macOS")
		end
		return "x86_64"
	elseif system.arch == "aarch64" or system.arch == "arm64" then
		return "aarch64"
	else
		error(`Unsupported architecture: {system.arch}`)
	end
end

local function downloadBinary(repo: string, tag: string, executableName: string): string
	tag = normalizeTag(tag)
	local asset = `lute-{osSlug()}-{archSlug()}.zip`
	local url = `https://github.com/{repo}/releases/download/{tag}/{asset}`

	local res = net.request(url, { method = "GET", headers = headers() })
	if not res.ok then
		error(`Failed to download {asset} from {tag}: HTTP {res.status}\n{string.sub(res.body, 1, 200)}`)
	end

	local reader = unzip.load(buffer.fromstring(res.body))

	local extracted: string? = nil
	reader:walk(function(entry, _depth)
		if extracted ~= nil or entry.isDirectory then
			return
		end
		if path.basename(entry.name) == executableName then
			extracted = reader:extract(entry, { type = "text" }) :: string
		end
	end)

	if extracted == nil then
		error(`Could not find {executableName} in {asset}`)
	end
	return extracted
end

return table.freeze({
	isNightlyTag = isNightlyTag,
	normalizeTag = normalizeTag,
	selectLatestNightlyTag = selectLatestNightlyTag,
	queryLatestTag = queryLatestTag,
	queryLatestNightlyTag = queryLatestNightlyTag,
	downloadBinary = downloadBinary,
})
