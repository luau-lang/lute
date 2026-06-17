local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local manifest = require("./manifest")
local path = require("@std/path")
local semver = require("./semver")
local store = require("./store")

type RegistryFixup = {
	read aliases: { [string]: string },
	read alias: string,
	read name: string,
}

type RegistryContext = {
	read fixups: { RegistryFixup },
	read names: { [string]: string },
	read requirements: { [string]: semver.Requirement },
	read sources: { [string]: string },
}

local function createRegistryContext(): RegistryContext
	return table.freeze({
		fixups = {},
		names = {},
		requirements = {},
		sources = {},
	})
end

local function getKey(spec: manifest.DependencySpec): string
	if spec.sourceKind == "github" then
		return `{spec.name}@{spec.rev}`
	end

	return spec.name
end

local function hasConflict(resolved: lockfile.LockfileDependency, incoming: manifest.DependencySpec): boolean
	if resolved.sourceKind ~= incoming.sourceKind then
		return true
	end

	if resolved.source ~= incoming.source then
		return true
	end

	if incoming.sourceKind == "github" then
		return resolved.rev ~= incoming.rev
	end

	return false
end

local function normalizePathDependency(
	spec: manifest.DependencySpec,
	contextDirectory: string,
	rootDirectory: string
): manifest.DependencySpec
	-- normalization is a no-op if it's not a path dependency
	if spec.sourceKind ~= "path" then
		return spec
	end

	local sourcePath = path.format(path.resolve(contextDirectory, spec.source))
	if not fs.exists(sourcePath) then
		error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
	end

	return table.freeze({
		name = spec.name,
		sourceKind = "path" :: "path",
		source = path.format(path.relative(rootDirectory, sourcePath)),
	})
end

-- Walk a dependency map and split it: registry specs become solver inputs (with a
-- pending fixup so we can write the resolved key back into `aliases` post-solve);
-- path/github specs are normalized and pushed onto the queue.
local function enqueueDependencies(
	queue: { manifest.DependencySpec },
	dependencies: { [string]: manifest.DependencySpec },
	contextDirectory: string,
	rootDirectory: string,
	registry: RegistryContext,
	requiredBy: string
): { [string]: string }
	local aliases: { [string]: string } = {}
	for dependencyAlias, dependencySpec in dependencies do
		if dependencySpec.sourceKind == "registry" then
			local sourceKey = `{requiredBy}:{dependencyAlias}`
			registry.requirements[sourceKey] = {
				name = dependencySpec.name,
				constraint = semver.parseConstraint(dependencySpec.version),
				requiredBy = requiredBy,
				aliasedAs = if dependencyAlias ~= dependencySpec.name then dependencyAlias else nil,
			}
			registry.sources[dependencySpec.name] = dependencySpec.source
			table.insert(registry.fixups, {
				aliases = aliases,
				alias = dependencyAlias,
				name = dependencySpec.name,
			})
		else
			local normalized = normalizePathDependency(dependencySpec, contextDirectory, rootDirectory)
			aliases[dependencyAlias] = getKey(normalized)
			table.insert(queue, normalized)
		end
	end
	return aliases
end

local function seedWorkspaceMembers(
	queue: { manifest.DependencySpec },
	rootDirectory: string,
	rootManifest: manifest.ProjectManifest,
	registry: RegistryContext
): { [string]: lockfile.LockfileMember }?
	if rootManifest.workspace == nil then
		return nil
	end
	local members: { [string]: lockfile.LockfileMember } = {}
	for _, memberPath in rootManifest.workspace do
		local memberDirectory = path.format(path.resolve(rootDirectory, memberPath))
		local memberManifest = manifest.parseFile(memberDirectory)
		local memberName = memberManifest.package.name
		if members[memberName] then
			error(
				`Duplicate workspace member name '{memberName}':\n`
					.. `  {members[memberName].path}\n`
					.. `  {memberPath}`
			)
		end
		local memberDependencies = enqueueDependencies(
			queue,
			memberManifest.package.dependencies,
			memberDirectory,
			rootDirectory,
			registry,
			memberName
		)
		members[memberName] = table.freeze({
			path = memberPath,
			dependencies = memberDependencies,
		})
		registry.names[memberName] = memberName
	end
	return table.freeze(members)
end

local function fetchSource(spec: manifest.DependencySpec, rootDirectory: string): string
	if spec.sourceKind == "path" then
		local sourcePath = path.format(path.resolve(rootDirectory, spec.source))
		if not fs.exists(sourcePath) then
			error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
		end
		return sourcePath
	elseif spec.sourceKind == "github" then
		store.ensureStoreDirectory()

		local key = getKey(spec)
		local sourcePath = store.getPackagePath(key)
		if not store.hasPackage(key) then
			github.installPackage(spec.source, spec.rev, sourcePath)
		end

		return sourcePath
	else
		error(`Unsupported source kind: {spec.sourceKind} for package {spec.name}`)
	end
end

local function shouldDeduplicate(
	key: string,
	spec: manifest.DependencySpec,
	packages: { [string]: lockfile.LockfileDependency },
	registry: RegistryContext
): boolean
	if packages[key] then
		if hasConflict(packages[key], spec) then
			error(
				`Source mismatch for package '{spec.name}':\n`
					.. `  resolved: {packages[key].source} ({packages[key].sourceKind})\n`
					.. `  incoming: {spec.source} ({spec.sourceKind})\n`
					.. `Both resolve to '{key}' but from different sources.`
			)
		else
			-- Already resolved at this exact version — deduplicate
			return true
		end
	end

	local conflictKey = registry.names[spec.name]
	if conflictKey then
		error(
			`Name conflict for package '{spec.name}':\n`
				.. `  resolved: {conflictKey}\n`
				.. `  incoming: {key}\n`
				.. `Two different sources claim the same package name.`
		)
	end

	-- new dependency
	registry.names[spec.name] = key
	return false
end

local function processSpecQueue(
	queue: { manifest.DependencySpec },
	rootDirectory: string,
	registry: RegistryContext
): { [string]: lockfile.LockfileDependency }
	local packages: { [string]: lockfile.LockfileDependency } = {}

	for _, spec in queue do
		local key = getKey(spec)
		if shouldDeduplicate(key, spec, packages, registry) then
			continue
		end

		local installPath = fetchSource(spec, rootDirectory)
		local depManifest = manifest.parseFile(installPath)
		local transitiveDependencies =
			enqueueDependencies(queue, depManifest.package.dependencies, installPath, rootDirectory, registry, key)

		packages[key] = table.freeze({
			name = spec.name,
			rev = if spec.sourceKind == "github" then spec.rev else nil,
			source = spec.source,
			sourceKind = spec.sourceKind,
			installPath = if spec.sourceKind == "path"
				then path.format(path.relative(rootDirectory, installPath))
				else store.toStorePath(key),
			dependencies = transitiveDependencies,
		})
	end

	-- "destroy" queue
	table.clear(queue)
	table.freeze(queue)

	return packages
end

-- Solve all collected registry requirements in one pass and stitch the resolved
-- versions into the package graph: emit one packages entry per resolved version,
-- and back-patch every fixup's alias table with the concrete `name@version` key.
local function solveRegistryRequirements(
	packages: { [string]: lockfile.LockfileDependency },
	registry: RegistryContext,
	universe: semver.Universe
)
	local resolution = semver.solve(universe, registry.requirements)

	for name, pkgVersion in resolution do
		local key = `{name}@{pkgVersion.versionString}`

		local transitiveDependencies: { [string]: string } = {}
		for alias, dependency in pkgVersion.dependencies do
			local resolvedDependency = resolution[dependency.name]
			assert(resolvedDependency ~= nil, `Solver produced an incomplete resolution: missing '{dependency.name}'`)
			transitiveDependencies[alias] = `{dependency.name}@{resolvedDependency.versionString}`
		end

		packages[key] = table.freeze({
			name = name,
			rev = pkgVersion.versionString,
			source = registry.sources[name] or name,
			sourceKind = "registry" :: "registry",
			installPath = store.toStorePath(key),
			dependencies = transitiveDependencies,
		})
	end

	for _, fix in registry.fixups do
		local pkgVersion = resolution[fix.name]
		assert(pkgVersion ~= nil, `Solver did not resolve registry dependency '{fix.name}'`)
		fix.aliases[fix.alias] = `{fix.name}@{pkgVersion.versionString}`
	end
end

local function resolve(rootDirectory: string, universe: semver.Universe?): lockfile.Lockfile
	local queue: { manifest.DependencySpec } = {}
	local registry = createRegistryContext()

	local rootManifest = manifest.parseFile(rootDirectory)
	registry.names[rootManifest.package.name] = rootManifest.package.name

	local dependencies = enqueueDependencies(
		queue,
		rootManifest.package.dependencies,
		rootDirectory,
		rootDirectory,
		registry,
		rootManifest.package.name
	)
	local members = seedWorkspaceMembers(queue, rootDirectory, rootManifest, registry)
	local packages = processSpecQueue(queue, rootDirectory, registry)

	if next(registry.requirements) ~= nil then
		assert(universe ~= nil, "Registry dependencies require a universe to be provided")
		solveRegistryRequirements(packages, registry, universe)
	end

	-- Freeze alias tables that we deliberately left open so registry fixups could
	-- write back into them. Package entries are already shallow-frozen.
	table.freeze(dependencies)
	if members ~= nil then
		for _, member in members do
			table.freeze(member.dependencies)
		end
	end
	for _, pkg in packages do
		table.freeze(pkg.dependencies)
	end
	table.freeze(packages)

	return table.freeze({
		version = 3,
		members = members,
		packages = packages,
		dependencies = dependencies,
	})
end

return {
	resolve = resolve,
}
