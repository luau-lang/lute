local fs = require("@std/fs")
local luau = require("@std/luau")
local manifest = require("./manifest")
local path = require("@std/path")
local registryUrlUtil = require("./registryurl")
local semver = require("./semver")
local store = require("./store")

export type LockfileDependency = {
	read name: string,
	read rev: string?,
	read source: string,
	read sourceKind: manifest.SourceKind,
	read target: string?,
	read installPath: string,
	read dependencies: { [string]: string },
	read devDependencies: { [string]: string }?,
	read registry: string?,
}

export type Lockfile = {
	read version: number,
	read packages: { [string]: LockfileDependency },
	read dependencies: { [string]: string },
	read devDependencies: { [string]: string }?,
	read overrides: { [string]: string }?,
	read registry: string?,
}

local function validateAliasMap(map: any, description: string)
	assert(typeof(map) == "table", `Expected {description} to be a table`)
	for alias, depKey in map do
		assert(typeof(alias) == "string", `Expected alias to be a string in {description}`)
		assert(typeof(depKey) == "string", `Expected dependency key to be a string in {description}`)
	end
	table.freeze(map)
end

local function validatePackageEntry(key: string, entry: any)
	assert(typeof(entry) == "table", `Expected table for dependency '{key}'`)
	assert(typeof(entry.name) == "string", `Expected 'name' field in dependency '{key}'`)
	assert(
		entry.rev == nil or typeof(entry.rev) == "string",
		`Expected 'rev' field to be a string or nil for dependency '{key}'`
	)
	assert(typeof(entry.source) == "string", `Expected 'source' field in dependency '{key}'`)
	assert(
		entry.target == nil or typeof(entry.target) == "string",
		`Expected 'target' field to be a string or nil for dependency '{key}'`
	)
	assert(
		manifest.isSourceKind(entry.sourceKind),
		`Expected 'sourceKind' to be 'path', 'github', or 'registry' for dependency '{key}', got '{entry.sourceKind}'`
	)
	assert(
		entry.target == nil or entry.sourceKind == "github",
		`Only github dependencies may have a 'target' field (dependency '{key}')`
	)
	assert(typeof(entry.installPath) == "string", `Expected 'installPath' field in dependency '{key}'`)
	assert(entry.dependencies ~= nil, `Expected 'dependencies' field in dependency '{key}'`)
	validateAliasMap(entry.dependencies, `'dependencies' of '{key}'`)
	if entry.devDependencies ~= nil then
		validateAliasMap(entry.devDependencies, `'devDependencies' of '{key}'`)
	end
	assert(
		entry.registry == nil or typeof(entry.registry) == "string",
		`Expected 'registry' field to be a string or nil for dependency '{key}'`
	)
end

local function parseLockfile(t: any): Lockfile
	assert(t ~= nil and typeof(t) == "table", "Expected lockfile to be a table")
	assert(t.version == 3 or t.version == 4, `Unsupported lockfile version: {t.version}`)
	assert(typeof(t.packages) == "table", "Expected 'packages' field in lockfile")
	assert(typeof(t.dependencies) == "table", "Expected 'dependencies' field in lockfile")

	for key, entry in t.packages do
		assert(typeof(key) == "string", "Expected package key to be a string")
		validatePackageEntry(key, entry)
	end
	table.freeze(t.packages)

	for _, rootMap in { t.dependencies, t.devDependencies } do
		if rootMap ~= nil then
			for alias, key in rootMap do
				assert(typeof(alias) == "string", "Expected dependency alias to be a string")
				assert(typeof(key) == "string", "Expected dependency key to be a string")
				assert(
					t.packages[key] ~= nil,
					`Dependency '{alias}' references package '{key}' which is not in packages`
				)
			end
			table.freeze(rootMap)
		end
	end

	if t.overrides ~= nil then
		assert(typeof(t.overrides) == "table", "Expected 'overrides' field to be a table")
		for name, value in t.overrides do
			assert(typeof(name) == "string", "Expected override key to be a string")
			assert(typeof(value) == "string", "Expected override value to be a string")
		end
		table.freeze(t.overrides)
	end

	assert(t.registry == nil or typeof(t.registry) == "string", "Expected 'registry' field to be a string or nil")

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

local function serializeOverrides(overrides: { [string]: manifest.DependencySpec }): { [string]: string }
	local result: { [string]: string } = {}
	for name, spec in overrides do
		if spec.sourceKind == "registry" then
			result[name] = `registry:{spec.source}@{spec.version}`
		elseif spec.sourceKind == "path" then
			result[name] = `path:{spec.source}`
		elseif spec.sourceKind == "github" then
			result[name] = `github:{spec.source}@{spec.rev}{if spec.target then `:{spec.target}` else ""}`
		end
	end
	return result
end

local function overridesMatch(locked: { [string]: string }?, current: { [string]: string }): (boolean, string?)
	for name, value in current do
		if locked == nil or locked[name] ~= value then
			return false, `override changed: {name}`
		end
	end

	if locked then
		for name in locked do
			if current[name] == nil then
				return false, `override removed: {name}`
			end
		end
	end

	return true, nil
end

local function getEffectiveRootSpec(
	spec: manifest.DependencySpec,
	overrides: { [string]: manifest.DependencySpec }
): manifest.DependencySpec
	return overrides[spec.name] or spec
end

local function isSameSource(pkg: LockfileDependency, spec: manifest.DependencySpec, rootDirectory: string): boolean
	if pkg.sourceKind ~= spec.sourceKind then
		return false
	end
	if spec.sourceKind == "path" then
		return path.format(path.resolve(rootDirectory, pkg.source)) == spec.directory
	end
	if pkg.source ~= spec.source then
		return false
	end
	if spec.sourceKind == "github" then
		return pkg.rev == spec.rev and pkg.target == spec.target
	end
	return true
end

local function lockedEntryMatches(
	lock: Lockfile,
	alias: string,
	key: string,
	spec: manifest.DependencySpec,
	rootDirectory: string
): (boolean, string?)
	local pkg = lock.packages[key]
	if pkg == nil then
		return false, `broken lockfile entry for: {alias}`
	end

	if not isSameSource(pkg, spec, rootDirectory) then
		return false, `{spec.sourceKind} source changed for: {alias}`
	end

	if spec.sourceKind == "registry" then
		local constraint = semver.parseConstraint(spec.version)
		local lockedVersion = semver.tryParse(pkg.rev :: string)
		if lockedVersion == nil or not semver.satisfies(lockedVersion, constraint) then
			return false, `registry constraint no longer satisfied for: {alias}`
		end
	end

	return true, nil
end

local function aliasMapMatches(
	locked: { [string]: string },
	expected: { [string]: manifest.DependencySpec },
	lock: Lockfile,
	overrides: { [string]: manifest.DependencySpec },
	rootDirectory: string
): (boolean, string?)
	for alias, spec in expected do
		local key = locked[alias]
		if key == nil then
			return false, `new dependency: {alias}`
		end

		local ok, reason = lockedEntryMatches(lock, alias, key, getEffectiveRootSpec(spec, overrides), rootDirectory)
		if not ok then
			return false, reason
		end
	end

	for alias in locked do
		if expected[alias] == nil then
			return false, `removed dependency: {alias}`
		end
	end

	return true, nil
end

local function satisfiesManifest(
	lock: Lockfile,
	rootManifest: manifest.ProjectManifest,
	rootDirectory: string,
	excludeDev: boolean
): (boolean, string?)
	local ok, reason = aliasMapMatches(
		lock.dependencies,
		rootManifest.package.dependencies,
		lock,
		rootManifest.overrides,
		rootDirectory
	)
	if not ok then
		return false, reason
	end

	if not excludeDev then
		ok, reason = aliasMapMatches(
			lock.devDependencies or {},
			rootManifest.package.devDependencies,
			lock,
			rootManifest.overrides,
			rootDirectory
		)
		if not ok then
			return false, reason
		end
	end

	local currentOverrides = serializeOverrides(rootManifest.overrides)
	local overridesOk, overridesReason = overridesMatch(lock.overrides, currentOverrides)
	if not overridesOk then
		return false, overridesReason
	end

	if not registryUrlUtil.equals(lock.registry, rootManifest.registry) then
		return false, "registry URL changed"
	end

	for key, pkg in lock.packages do
		if pkg.sourceKind == "registry" and pkg.registry then
			local expectedInstallPath = store.toStorePath(store.qualifyRegistryKey(key, pkg.registry))
			if pkg.installPath ~= expectedInstallPath then
				return false, `registry store path changed: {key}`
			end
		elseif pkg.sourceKind == "github" then
			if pkg.rev == nil then
				return false, `github revision missing: {key}`
			end
			local expectedInstallPath = store.getGitHubInstallPath(pkg.source, pkg.rev, pkg.target)
			if pkg.installPath ~= expectedInstallPath then
				return false, `github store path changed: {key}`
			end
		end
	end

	return true, nil
end

local function getReachablePackageKeys(lock: Lockfile, includeDev: boolean): { [string]: boolean }
	local reachable: { [string]: boolean } = {}

	local function visit(key: string)
		if reachable[key] then
			return
		end

		reachable[key] = true
		local pkg = lock.packages[key]
		if pkg then
			for _, dependencyKey in pkg.dependencies do
				visit(dependencyKey)
			end
			if includeDev and pkg.devDependencies then
				for _, dependencyKey in pkg.devDependencies do
					visit(dependencyKey)
				end
			end
		end
	end

	for _, key in lock.dependencies do
		visit(key)
	end
	if includeDev and lock.devDependencies then
		for _, key in lock.devDependencies do
			visit(key)
		end
	end

	return reachable
end

return {
	parseFile = parseFile,
	tryParseFile = tryParseFile,
	satisfiesManifest = satisfiesManifest,
	isSameSource = isSameSource,
	getReachablePackageKeys = getReachablePackageKeys,
	serializeOverrides = serializeOverrides,
}
