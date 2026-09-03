local authenticationStore = require("./authenticationstore")
local credentials = require("./credentials")
local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local semver = require("./semver")
local system = require("@std/system")
local unzip = require("../extern/unzip")

local function parseHost(registryUrl: string): string
	local host = registryUrl:match("^https?://([^/]+)")
	assert(host, `Could not parse host from registry URL: {registryUrl}`)
	return host
end

local function getAuthenticationToken(registryUrl: string): string?
	local token = process.env.LOOM_REGISTRY_TOKEN
	if token ~= nil and token ~= "" then
		return token
	end

	local host = parseHost(registryUrl)

	local providedToken = credentials.resolveToken({
		protocol = "https",
		host = host,
	})
	if providedToken ~= nil and providedToken ~= "" then
		return providedToken
	end

	local store = authenticationStore.loadAuthenticationStore()
	local entry = store[host]
	if typeof(entry) == "table" and typeof(entry.token) == "string" and entry.token ~= "" then
		return entry.token
	end

	return nil
end

local function registryRequest(registryUrl: string, endpoint: string): string
	local url = `{registryUrl}{endpoint}`
	local token = getAuthenticationToken(registryUrl)

	local headers: { [string]: string } = {
		["User-Agent"] = "lute-pkg",
		["Accept"] = "application/json",
	}

	if token ~= nil then
		headers["Authorization"] = `Bearer {token}`
	end

	local response = net.request(url, { method = "GET", headers = headers })

	if response.status == 401 or response.status == 403 then
		error(
			`Registry authentication failed for {url}: HTTP {response.status}. `
				.. `Run \`lute pkg authenticate --domain {parseHost(registryUrl)}\` to set credentials.`
		)
	end

	if response.status == 404 then
		error(`Not found: {url}`)
	end

	if not response.ok then
		error(`Registry request failed: {url}: HTTP {response.status}\n{string.sub(response.body, 1, 200)}`)
	end

	return response.body
end

local function indexToPackageVersions(entries: any, packageName: string): { semver.PackageVersion }
	local versions: { semver.PackageVersion } = {}

	for _, entry in entries do
		if entry.yanked == true then
			continue
		end

		local version = semver.tryParse(entry.version)
		if version == nil then
			continue
		end

		local dependencies: { [string]: semver.Requirement } = {}
		if entry.dependencies then
			for _, dep in entry.dependencies do
				local alias = if dep.alias and dep.alias ~= "" then dep.alias else dep.name
				dependencies[alias] = table.freeze({
					name = dep.name,
					constraint = semver.parseConstraint(dep.versionRequirement),
				})
			end
		end

		table.insert(
			versions,
			table.freeze({
				name = packageName,
				version = version,
				versionString = entry.version,
				dependencies = table.freeze(dependencies),
			})
		)
	end

	return versions
end

local function fetchPackageIndex(registryUrl: string, packageName: string): any
	local body = registryRequest(registryUrl, `/api/v1/package-index/{packageName}`)
	local entries = json.deserialize(body) :: any
	assert(entries ~= nil and typeof(entries) == "table", `Invalid package index response for '{packageName}'`)
	return entries
end

local function fetchContentUrl(registryUrl: string, packageName: string, version: string): string
	local body = registryRequest(registryUrl, `/api/v1/package-content-url/{packageName}/{version}`)
	local data = json.deserialize(body) :: any
	assert(data ~= nil and typeof(data) == "table", `Invalid content URL response for '{packageName}@{version}'`)
	assert(
		typeof(data.contentUrl) == "string" and data.contentUrl ~= "",
		`Missing contentUrl in response for '{packageName}@{version}'`
	)
	return data.contentUrl
end

local function fetchUniverse(registryUrl: string, packageNames: { string }): semver.Universe
	local universe: semver.Universe = {}
	local fetched: { [string]: boolean } = {}
	local queue: { string } = {}

	for _, name in packageNames do
		if not fetched[name] then
			table.insert(queue, name)
			fetched[name] = true
		end
	end

	local queueIndex = 1
	while queueIndex <= #queue do
		local packageName = queue[queueIndex]
		queueIndex += 1

		local entries = fetchPackageIndex(registryUrl, packageName)
		local versions = indexToPackageVersions(entries, packageName)
		universe[packageName] = versions

		for _, pkgVersion in versions do
			for _, dep in pkgVersion.dependencies do
				if not fetched[dep.name] then
					table.insert(queue, dep.name)
					fetched[dep.name] = true
				end
			end
		end
	end

	return universe
end

local function installZipArchive(content: string, installPath: string)
	local reader = unzip.load(buffer.fromstring(content))

	reader:walk(function(entry, _depth)
		if entry.isDirectory then
			return
		end

		local entryContent = reader:extract(entry, { type = "text" }) :: string

		local safePath = entry:getSafePath()
		if not safePath then
			error(`Unsafe path in registry package archive: {entry.name}`)
		end

		local outputPath = `{installPath}/{safePath}`
		fs.createDirectory(path.dirname(outputPath), { makeParents = true })
		fs.writeStringToFile(outputPath, entryContent)
	end)
end

local function installPackage(registryUrl: string, packageName: string, version: string, installPath: string)
	local contentUrl = fetchContentUrl(registryUrl, packageName, version)
	local token = getAuthenticationToken(registryUrl)
	local headers: { [string]: string } = {
		["User-Agent"] = "lute-pkg",
	}
	if token ~= nil then
		headers["Authorization"] = `Bearer {token}`
	end

	local response = net.request(contentUrl, { method = "GET", headers = headers })
	if not response.ok then
		error(`Failed to download package '{packageName}@{version}' from {contentUrl}: HTTP {response.status}`)
	end

	local safeName = string.gsub(`{packageName}-{version}`, "[^%w%-_.]", "-")
	local tempDir = path.format(path.join(system.tmpdir(), `lute-pkg-registry-{safeName}`))

	if fs.exists(tempDir) then
		fs.removeDirectory(tempDir, { recursive = true })
	end

	xpcall(installZipArchive, function(err)
		if fs.exists(tempDir) then
			fs.removeDirectory(tempDir, { recursive = true })
		end
		error(err, 0)
	end, response.body, tempDir)

	fs.move(tempDir, installPath)
end

return {
	fetchUniverse = fetchUniverse,
	installPackage = installPackage,
	indexToPackageVersions = indexToPackageVersions,
}
