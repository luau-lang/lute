local authenticationStore = require("./authenticationstore")
local credentials = require("./credentials")
local fs = require("@std/fs")
local json = require("@std/json")
local manifest = require("./manifest")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local semver = require("./semver")
local system = require("@std/system")
local unzip = require("../extern/unzip")

export type IndexDependency = {
	read name: string,
	read alias: string?,
	read versionRequirement: string,
}

export type IndexEntry = {
	read name: string,
	read version: string,
	read yanked: boolean?,
	read dependencies: { IndexDependency },
}

local function parseHost(url: string): string
	local host = url:match("^https?://([^/]+)")
	if not host then
		error(`Invalid registry URL: {url}`)
	end
	return host
end

local function getRegistryAuthenticationToken(registryUrl: string): string?
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

	local authStore = authenticationStore.loadAuthenticationStore()
	local entry = authStore[host]
	if typeof(entry) == "table" and typeof(entry.token) == "string" and entry.token ~= "" then
		return entry.token
	end

	return nil
end

local function registryRequest(registryUrl: string, apiPath: string): string
	local url = `{registryUrl}{apiPath}`
	local headers: { [string]: string } = {
		["User-Agent"] = "lute-pkg",
		["Accept"] = "application/json",
	}

	local token = getRegistryAuthenticationToken(registryUrl)
	if token ~= nil then
		headers["Authorization"] = `Bearer {token}`
	end

	local response = net.request(url, { method = "GET", headers = headers })

	if response.status == 401 or response.status == 403 then
		local host = parseHost(registryUrl)
		error(
			`Authentication failed for registry '{registryUrl}'. Run \`lute pkg authenticate --domain {host} --token <token>\` to configure credentials.`
		)
	end

	if not response.ok then
		error(`Registry request failed: GET {url} returned HTTP {response.status}\n{string.sub(response.body, 1, 200)}`)
	end

	return response.body
end

local function fetchPackageIndex(registryUrl: string, packageName: string): { IndexEntry }
	local ok, body = pcall(registryRequest, registryUrl, `/api/v1/package-index/{packageName}`)
	if not ok then
		if string.find(body :: string, "HTTP 404") then
			error(`Package '{packageName}' not found in registry '{registryUrl}'`)
		end
		error(body :: string)
	end

	local parseOk, entries = pcall(json.deserialize, body)
	if not parseOk then
		error(`Failed to parse registry response for '{packageName}': {entries}`)
	end

	return entries :: { IndexEntry }
end

local function indexToPackageVersions(entries: { IndexEntry }): { semver.PackageVersion }
	local versions: { semver.PackageVersion } = {}

	for _, entry in entries do
		if entry.yanked then
			continue
		end

		local version = semver.parse(entry.version)
		local dependencies: { [string]: semver.Requirement } = {}

		if entry.dependencies then
			for _, dep in entry.dependencies do
				local alias = dep.alias or dep.name
				dependencies[alias] = table.freeze({
					name = dep.name,
					constraint = semver.parseConstraint(dep.versionRequirement),
					aliasedAs = if dep.alias and dep.alias ~= dep.name then dep.alias else nil,
				})
			end
		end

		table.insert(
			versions,
			table.freeze({
				name = entry.name,
				version = version,
				versionString = entry.version,
				dependencies = table.freeze(dependencies),
			})
		)
	end

	table.sort(versions, function(a, b)
		return semver.compare(a.version, b.version) > 0
	end)

	return versions
end

local function buildUniverse(
	packageNames: { string },
	registryAssignments: { [string]: string },
	registryMap: manifest.RegistryMap,
	defaultRegistry: string?
): semver.Universe
	local universe: semver.Universe = {}
	local fetched: { [string]: boolean } = {}
	local toFetch: { string } = table.clone(packageNames)

	while #toFetch > 0 do
		local nextRound: { string } = {}

		for _, name in toFetch do
			if fetched[name] then
				continue
			end
			fetched[name] = true

			local registryName = registryAssignments[name] or defaultRegistry
			if not registryName then
				error(`No registry configured for package '{name}'`)
			end

			local registryConfig = registryMap[registryName]
			if not registryConfig then
				error(`Registry '{registryName}' is not defined (needed for package '{name}')`)
			end

			local entries = fetchPackageIndex(registryConfig.url, name)
			local versions = indexToPackageVersions(entries)
			universe[name] = versions

			for _, version in versions do
				for _, dep in version.dependencies do
					if not fetched[dep.name] and not universe[dep.name] then
						table.insert(nextRound, dep.name)
					end
					if not registryAssignments[dep.name] then
						registryAssignments[dep.name] = registryName
					elseif registryAssignments[dep.name] ~= registryName then
						error(
							`Conflicting registry for '{dep.name}': '{registryAssignments[dep.name]}' vs '{registryName}' (from transitive dependency in '{name}')`
						)
					end
				end
			end
		end

		toFetch = nextRound
	end

	return universe
end

local function fetchContentUrl(registryUrl: string, packageName: string, version: string): string
	local ok, body = pcall(registryRequest, registryUrl, `/api/v1/package-content-url/{packageName}/{version}`)
	if not ok then
		if string.find(body :: string, "HTTP 404") then
			error(`No content found for '{packageName}@{version}' in registry '{registryUrl}'`)
		end
		error(body :: string)
	end

	local parseOk, data = pcall(json.deserialize, body)
	if not parseOk then
		error(`Failed to parse content URL response for '{packageName}@{version}': {data}`)
	end

	local contentUrl = (data :: any).contentUrl
	if typeof(contentUrl) ~= "string" or contentUrl == "" then
		error(`Registry returned invalid content URL for '{packageName}@{version}'`)
	end

	return contentUrl
end

local function installZipArchive(content: string, installPath: string)
	local reader = unzip.load(buffer.fromstring(content))

	reader:walk(function(entry, _depth)
		if entry.isDirectory then
			return
		end

		local content = reader:extract(entry, { type = "text" }) :: string

		local safePath = entry:getSafePath()
		if not safePath then
			error(`Unsafe path in registry package archive: {entry.name}`)
		end

		local outputPath = `{installPath}/{safePath}`
		fs.createDirectory(path.dirname(outputPath), { makeParents = true })
		fs.writeStringToFile(outputPath, content)
	end)
end

local function installPackage(registryUrl: string, packageName: string, version: string, installPath: string): ()
	local contentUrl = fetchContentUrl(registryUrl, packageName, version)

	local response = net.request(contentUrl, { method = "GET" })
	if not response.ok then
		error(
			`Failed to download package content for '{packageName}@{version}': HTTP {response.status}\n{string.sub(
				response.body,
				1,
				200
			)}`
		)
	end

	local safeName = string.gsub(`{packageName}-{version}`, "[^%w%-_.]", "-")
	local tempDir = path.format(path.join(system.tmpdir(), `lute-pkg-install-{safeName}`))

	if fs.exists(tempDir) then
		fs.removeDirectory(tempDir, { recursive = true })
	end

	local extractErr: string? = nil
	local ok = xpcall(installZipArchive, function(err)
		if fs.exists(tempDir) then
			fs.removeDirectory(tempDir, { recursive = true })
		end
		extractErr = err
	end, response.body, tempDir)

	if not ok then
		error(extractErr, 0)
	end

	fs.move(tempDir, installPath)
end

return {
	buildUniverse = buildUniverse,
	installPackage = installPackage,
	fetchPackageIndex = fetchPackageIndex,
	indexToPackageVersions = indexToPackageVersions,
}
