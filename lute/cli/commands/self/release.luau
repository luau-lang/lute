local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")
local system = require("@std/system")

local binary = require("./binary")
local paths = require("./paths")
local unzip = require("../pkg/loom-core/extern/unzip")

local REPO = "luau-lang/lute"

local function normalizeTag(tag: string): string
	local trimmed = stringext.trim(tag)
	if trimmed == "" then
		error("Release version cannot be empty")
	end
	local stripped = if string.match(trimmed, "^[vV]") then string.sub(trimmed, 2) else trimmed
	return `v{string.lower(stripped)}`
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

local function queryLatestTag(): string
	local url = `https://api.github.com/repos/{REPO}/releases/latest`
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

local function downloadBinary(tag: string, destination: string)
	tag = normalizeTag(tag)
	local asset = `lute-{osSlug()}-{archSlug()}.zip`
	local url = `https://github.com/{REPO}/releases/download/{tag}/{asset}`

	local res = net.request(url, { method = "GET", headers = headers() })
	if not res.ok then
		error(`Failed to download {asset} from {tag}: HTTP {res.status}\n{string.sub(res.body, 1, 200)}`)
	end

	local reader = unzip.load(buffer.fromstring(res.body))
	local exeName = paths.exeName()

	local extracted: string? = nil
	reader:walk(function(entry, _depth)
		if extracted ~= nil or entry.isDirectory then
			return
		end
		if path.basename(entry.name) == exeName then
			extracted = reader:extract(entry, { type = "text" }) :: string
		end
	end)

	if extracted == nil then
		error(`Could not find {exeName} in {asset}`)
	end
	binary.installBinary(extracted, destination)
end

return table.freeze({
	normalizeTag = normalizeTag,
	queryLatestTag = queryLatestTag,
	downloadBinary = downloadBinary,
})
