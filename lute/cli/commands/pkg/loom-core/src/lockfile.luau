local fs = require("@std/fs")
local luau = require("@std/luau")
local manifest = require("./manifest")
local path = require("@std/path")
local registryUrlUtil = require("./registryurl")
local semver = require("./semver")
local store = require("./store")
local workspace = require("./workspace")

export type LockfileDependency = {
	read name: string,
	read rev: string?,
	read source: string,
	read sourceKind: manifest.SourceKind,
	read installPath: string,
	read dependencies: { [string]: string },
	read registry: string?,
}

export type Lockfile = {
	read version: number,
	read packages: { [string]: LockfileDependency },
	read dependencies: { [string]: { [string]: string } },
	read overrides: { [string]: string }?,
	read registry: string?,
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
	assert(
		entry.registry == nil or typeof(entry.registry) == "string",
		`Expected 'registry' field to be a string or nil for dependency '{key}'`
	)
end

local function parseLockfile(t: any): Lockfile
	assert(t ~= nil and typeof(t) == "table", "Expected lockfile to be a table")
	assert(t.version == 4, `Unsupported lockfile version: {t.version}`)
	assert(typeof(t.packages) == "table", "Expected 'packages' field in lockfile")
	assert(typeof(t.dependencies) == "table", "Expected 'dependencies' field in lockfile")

	for key, entry in t.packages do
		assert(typeof(key) == "string", "Expected package key to be a string")
		validatePackageEntry(key, entry)
	end
	table.freeze(t.packages)

	for member, memberDependencies in t.dependencies do
		assert(typeof(member) == "string", "Expected member name to be a string")
		assert(typeof(memberDependencies) == "table", `Expected dependencies for member '{member}' to be a table`)
		for alias, key in memberDependencies do
			assert(typeof(alias) == "string", `Expected dependency alias to be a string for member '{member}'`)
			assert(typeof(key) == "string", `Expected dependency key to be a string for member '{member}'`)
			assert(
				t.packages[key] ~= nil,
				`Dependency '{member}:{alias}' references package '{key}' which is not in packages`
			)
		end
		table.freeze(memberDependencies)
	end
	table.freeze(t.dependencies)

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
			result[name] = spec.version
		elseif spec.sourceKind == "path" then
			result[name] = `path:{spec.source}`
		elseif spec.sourceKind == "github" then
			result[name] = `github:{spec.source}@{spec.rev}`
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

local function normalizeMemberPathSpec(
	spec: manifest.DependencySpec,
	memberDirectory: string,
	rootDirectory: string
): manifest.DependencySpec
	if spec.sourceKind ~= "path" then
		return spec
	end
	
	if memberDirectory == rootDirectory then
		return spec
	end

	local sourcePath = path.format(path.resolve(memberDirectory, spec.source))
	if not fs.exists(sourcePath) then
		return spec
	end

	return table.freeze({
		name = spec.name,
		sourceKind = "path" :: "path",
		source = path.format(path.relative(rootDirectory, sourcePath)),
	}) :: manifest.PathDependencySpec
end

local function satisfiesManifest(
	lock: Lockfile,
	rootWorkspace: workspace.Workspace,
	excludeDev: boolean
): (boolean, string?)
	local seenMembers: { [string]: boolean } = {}
	for _, member in rootWorkspace.members do
		seenMembers[member.name] = true
		local expectedAliases: { [string]: manifest.DependencySpec } = {}
		for alias, spec in member.package.dependencies do
			expectedAliases[alias] = spec
		end
		if not excludeDev then
			for alias, spec in member.package.devDependencies do
				expectedAliases[alias] = spec
			end
		end

		local lockedDependencies = lock.dependencies[member.name]
		if lockedDependencies == nil then
			return false, `new workspace member: {member.name}`
		end

		for alias, spec in expectedAliases do
			spec = normalizeMemberPathSpec(spec, member.directory, rootWorkspace.rootDirectory)
			spec = getEffectiveRootSpec(spec, rootWorkspace.overrides)

			local key = lockedDependencies[alias]
			if key == nil then
				return false, `new dependency: {member.name}:{alias}`
			end

			local pkg = lock.packages[key]
			if pkg == nil then
				return false, `broken lockfile entry for: {member.name}:{alias}`
			end

			if pkg.sourceKind ~= spec.sourceKind then
				return false, `source kind changed for: {member.name}:{alias}`
			end

			if spec.sourceKind == "github" then
				if pkg.source ~= spec.source or pkg.rev ~= spec.rev then
					return false, `github source changed for: {member.name}:{alias}`
				end
			elseif spec.sourceKind == "path" then
				if pkg.source ~= spec.source then
					return false, `path changed for: {member.name}:{alias}`
				end
			elseif spec.sourceKind == "registry" then
				if pkg.source ~= spec.source then
					return false, `registry source changed for: {member.name}:{alias}`
				end
				if not registryUrlUtil.equals(pkg.registry, rootWorkspace.registry) then
					return false, `registry URL changed for: {member.name}:{alias}`
				end
				local constraint = semver.parseConstraint(spec.version)
				local lockedVersion = semver.tryParse(pkg.rev :: string)
				if lockedVersion == nil or not semver.satisfies(lockedVersion, constraint) then
					return false, `registry constraint no longer satisfied for: {member.name}:{alias}`
				end
			end
		end

		for alias in lockedDependencies do
			if not excludeDev and expectedAliases[alias] == nil then
				return false, `removed dependency: {member.name}:{alias}`
			end
		end
	end

	for member in lock.dependencies do
		if not seenMembers[member] then
			return false, `removed workspace member: {member}`
		end
	end

	local currentOverrides = serializeOverrides(rootWorkspace.overrides)
	local overridesOk, overridesReason = overridesMatch(lock.overrides, currentOverrides)
	if not overridesOk then
		return false, overridesReason
	end

	if not registryUrlUtil.equals(lock.registry, rootWorkspace.registry) then
		return false, "registry URL changed"
	end

	for key, pkg in lock.packages do
		if pkg.sourceKind == "registry" and pkg.registry then
			local expectedInstallPath = store.toStorePath(store.qualifyRegistryKey(key, pkg.registry))
			if pkg.installPath ~= expectedInstallPath then
				return false, `registry store path changed: {key}`
			end
		end
	end

	return true, nil
end

local function getReachablePackageKeys(lock: Lockfile, rootPackageKeys: { [string]: boolean }): { [string]: boolean }
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
		end
	end

	for key in rootPackageKeys do
		visit(key)
	end

	return reachable
end

return {
	parseFile = parseFile,
	tryParseFile = tryParseFile,
	satisfiesManifest = satisfiesManifest,
	getReachablePackageKeys = getReachablePackageKeys,
	serializeOverrides = serializeOverrides,
}
