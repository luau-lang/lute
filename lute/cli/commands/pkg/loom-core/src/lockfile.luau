local fs = require("@std/fs")
local luau = require("@std/luau")
local manifest = require("./manifest")
local semver = require("./semver")

export type LockfileDependency = {
	read name: string,
	read rev: string?,
	read source: string,
	read sourceKind: manifest.SourceKind,
	read installPath: string,
	read dependencies: { [string]: string },
}

export type Lockfile = {
	read version: number,
	read packages: { [string]: LockfileDependency },
	read dependencies: { [string]: string },
}

local function validatePackageEntry(key: string, entry: any)
	assert(typeof(entry) == "table", `Expected table for dependency '{key}'`)
	assert(typeof(entry.name) == "string", `Expected 'name' field in dependency '{key}'`)
	assert(
		entry.rev == nil or typeof(entry.rev) == "string",
		`Expected 'rev' field to be a string or nil for dependency '{key}'`
	)
	assert(typeof(entry.source) == "string", `Expected 'source' field in dependency '{key}'`)
	assert(
		manifest.isSourceKind(entry.sourceKind),
		`Expected 'sourceKind' to be 'path', 'github', or 'registry' for dependency '{key}', got '{entry.sourceKind}'`
	)
	assert(typeof(entry.installPath) == "string", `Expected 'installPath' field in dependency '{key}'`)
	assert(typeof(entry.dependencies) == "table", `Expected 'dependencies' field in dependency '{key}'`)
	for alias, depKey in entry.dependencies do
		assert(typeof(alias) == "string", `Expected alias to be a string for dependency '{key}'`)
		assert(typeof(depKey) == "string", `Expected dependency key to be a string for dependency '{key}'`)
	end
	table.freeze(entry.dependencies)
end

local function parseLockfile(t: any): Lockfile
	assert(t ~= nil and typeof(t) == "table", "Expected lockfile to be a table")
	assert(t.version == 3, `Unsupported lockfile version: {t.version}`)
	assert(typeof(t.packages) == "table", "Expected 'packages' field in lockfile")
	assert(typeof(t.dependencies) == "table", "Expected 'dependencies' field in lockfile")

	for key, entry in t.packages do
		assert(typeof(key) == "string", "Expected package key to be a string")
		validatePackageEntry(key, entry)
	end
	table.freeze(t.packages)

	for alias, key in t.dependencies do
		assert(typeof(alias) == "string", "Expected dependency alias to be a string")
		assert(typeof(key) == "string", "Expected dependency key to be a string")
		assert(t.packages[key] ~= nil, `Dependency '{alias}' references package '{key}' which is not in packages`)
	end
	table.freeze(t.dependencies)

	return table.freeze(t)
end

local function parseFile(lockfilePath: string): Lockfile
	local t = luau.loadModule(lockfilePath)
	return parseLockfile(t)
end

local function tryParseFile(lockfilePath: string): Lockfile?
	if not fs.exists(lockfilePath) then
		return nil
	end
	local ok, result = pcall(parseFile, lockfilePath)
	if not ok then
		return nil
	end
	return result
end

local function satisfiesManifest(
	lock: Lockfile,
	rootManifest: manifest.ProjectManifest,
	excludeDev: boolean
): (boolean, string?)
	local expectedAliases: { [string]: manifest.DependencySpec } = {}

	for alias, spec in rootManifest.package.dependencies do
		expectedAliases[alias] = spec
	end

	if not excludeDev then
		for alias, spec in rootManifest.package.devDependencies do
			expectedAliases[alias] = spec
		end
	end

	for alias, spec in expectedAliases do
		local key = lock.dependencies[alias]
		if key == nil then
			return false, `new dependency: {alias}`
		end

		local pkg = lock.packages[key]
		if pkg == nil then
			return false, `broken lockfile entry for: {alias}`
		end

		if pkg.sourceKind ~= spec.sourceKind then
			return false, `source kind changed for: {alias}`
		end

		if spec.sourceKind == "github" then
			if pkg.source ~= spec.source or pkg.rev ~= spec.rev then
				return false, `github source changed for: {alias}`
			end
		elseif spec.sourceKind == "path" then
			if pkg.source ~= spec.source then
				return false, `path changed for: {alias}`
			end
		elseif spec.sourceKind == "registry" then
			local constraint = semver.parseConstraint(spec.version)
			local lockedVersion = semver.tryParse(pkg.rev :: string)
			if lockedVersion == nil or not semver.satisfies(lockedVersion, constraint) then
				return false, `registry constraint no longer satisfied for: {alias}`
			end
		end
	end

	for alias in lock.dependencies do
		if expectedAliases[alias] == nil then
			return false, `removed dependency: {alias}`
		end
	end

	return true, nil
end

return {
	parseFile = parseFile,
	tryParseFile = tryParseFile,
	satisfiesManifest = satisfiesManifest,
}
