local authenticationStore = require("./authenticationstore")
local credentials = require("./credentials")
local json = require("@std/json")
local net = require("@std/net")
local process = require("@std/process")
local registryUrlUtil = require("./registryurl")
local semver = require("./semver")

local function getAuthenticationToken(registryUrl: string): string?
	local token = process.env.LOOM_REGISTRY_TOKEN
	if token ~= nil and token ~= "" then
		return token
	end

	local parsedUrl = registryUrlUtil.parse(registryUrl)

	local providedToken = credentials.resolveToken({
		protocol = parsedUrl.protocol,
		host = parsedUrl.host,
	})
	if providedToken ~= nil and providedToken ~= "" then
		return providedToken
	end

	local store = authenticationStore.loadAuthenticationStore()
	local entry = store[parsedUrl.host]
	if typeof(entry) == "table" and typeof(entry.token) == "string" and entry.token ~= "" then
		return entry.token
	end

	return nil
end

local function registryRequest(registryUrl: string, endpoint: string): string
	local url = `{registryUrlUtil.normalize(registryUrl)}{endpoint}`
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
		local parsedUrl = registryUrlUtil.parse(registryUrl)
		error(
			`Registry authentication failed for {url}: HTTP {response.status}. `
				.. `Run \`lute pkg auth --domain {parsedUrl.host}\` to set credentials.`
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
		assert(
			typeof(entry.name) == "string" and entry.name == packageName,
			`Package index for '{packageName}' contained an entry for a different package`
		)

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
				name = entry.name,
				version = version,
				versionString = entry.version,
				dependencies = table.freeze(dependencies),
			})
		)
	end

	return versions
end

local function fetchPackageIndex(registryUrl: string, packageSource: string): any
	local body = registryRequest(registryUrl, `/api/v1/package-index/{packageSource}`)
	local entries = json.deserialize(body) :: any
	assert(entries ~= nil and typeof(entries) == "table", `Invalid package index response for '{packageSource}'`)
	return entries
end

type PackageRequest = {
	name: string,
	source: string,
}

local function fetchUniverse(registryUrl: string, packageRequests: { PackageRequest }): semver.Universe
	local universe: semver.Universe = {}
	local fetched: { [string]: boolean } = {}
	local queue: { PackageRequest } = {}

	for _, packageRequest in packageRequests do
		if not fetched[packageRequest.name] then
			table.insert(queue, packageRequest)
			fetched[packageRequest.name] = true
		end
	end

	local queueIndex = 1
	while queueIndex <= #queue do
		local packageRequest = queue[queueIndex]
		queueIndex += 1

		local entries = fetchPackageIndex(registryUrl, packageRequest.source)
		local versions = indexToPackageVersions(entries, packageRequest.name)
		universe[packageRequest.name] = versions

		for _, pkgVersion in versions do
			for _, dep in pkgVersion.dependencies do
				if not fetched[dep.name] then
					table.insert(queue, {
						name = dep.name,
						source = dep.name,
					})
					fetched[dep.name] = true
				end
			end
		end
	end

	return universe
end

return {
	fetchUniverse = fetchUniverse,
	indexToPackageVersions = indexToPackageVersions,
}
