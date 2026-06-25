local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local manifest = require("./manifest")
local path = require("@std/path")
local semver = require("./semver")
local store = require("./store")

type RegistryPatch = {
	read parentAliases: { [string]: string },
	read alias: string,
	read name: string,
}

type RegistryContext = {
	read patches: { RegistryPatch },
	read requirements: { [string]: semver.Requirement },
	read sources: { [string]: string },
}

local function createRegistryContext(): RegistryContext
	return table.freeze({
		patches = {},
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
	installPath: string,
	rootDirectory: string
): manifest.DependencySpec
	-- normalization is a no-op if it's not a path dependency
	if spec.sourceKind ~= "path" then
		return spec
	end

	local sourcePath = path.format(path.resolve(installPath, spec.source))
	if not fs.exists(sourcePath) then
		error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
	end

	return table.freeze({
		name = spec.name,
		sourceKind = "path" :: "path",
		source = path.format(path.relative(rootDirectory, sourcePath)),
	})
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

export type ResolveOptions = {
	read excludeDev: boolean?,
}

local function shouldProcess(
	spec: manifest.DependencySpec,
	packages: { [string]: lockfile.LockfileDependency }
): boolean
	local key = getKey(spec)

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
			return false
		end
	end

	return true
end

local function enqueueDependencies(
	queue: { manifest.DependencySpec },
	registry: RegistryContext,
	dependencies: { [string]: manifest.DependencySpec },
	installPath: string,
	rootDirectory: string,
	requiredBy: string,
	existingAliases: { [string]: string }?
): { [string]: string }
	local aliases: { [string]: string } = existingAliases or {}
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
			table.insert(registry.patches, {
				parentAliases = aliases,
				alias = dependencyAlias,
				name = dependencySpec.name,
			})
		else
			local normalized = normalizePathDependency(dependencySpec, installPath, rootDirectory)
			aliases[dependencyAlias] = getKey(normalized)
			table.insert(queue, normalized)
		end
	end
	return aliases
end

local function processSpecQueue(
	queue: { manifest.DependencySpec },
	registry: RegistryContext,
	rootDirectory: string
): { [string]: lockfile.LockfileDependency }
	local packages: { [string]: lockfile.LockfileDependency } = {}

	for _, spec in queue do
		if not shouldProcess(spec, packages) then
			continue
		end

		local installPath = fetchSource(spec, rootDirectory)
		local dependencyManifest = manifest.parseFile(installPath)

		local key = getKey(spec)
		local transitiveDependencies = enqueueDependencies(
			queue,
			registry,
			dependencyManifest.package.dependencies,
			installPath,
			rootDirectory,
			key
		)

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

local function solveRegistryRequirements(
	packages: { [string]: lockfile.LockfileDependency },
	registry: RegistryContext,
	universe: semver.Universe
)
	local resolution = semver.solve(universe, registry.requirements)

	-- Solver returns slot-keyed entries; build a name lookup for dependency stitching.
	local versionsByPackageName: { [string]: semver.PackageVersion } = {}
	for _, pkgVersion in resolution do
		versionsByPackageName[pkgVersion.name] = pkgVersion
	end

	for _, pkgVersion in resolution do
		local name = pkgVersion.name
		local key = `{name}@{pkgVersion.versionString}`

		local transitiveDependencies: { [string]: string } = {}
		for alias, dependency in pkgVersion.dependencies do
			local resolvedVersion = versionsByPackageName[dependency.name]
			assert(resolvedVersion ~= nil, `Solver produced an incomplete resolution: missing '{dependency.name}'`)

			transitiveDependencies[alias] = `{dependency.name}@{resolvedVersion.versionString}`
		end

		packages[key] = table.freeze({
			name = name,
			rev = pkgVersion.versionString,
			source = registry.sources[name] or name,
			sourceKind = "registry" :: "registry",
			installPath = store.toStorePath(key),
			dependencies = table.freeze(transitiveDependencies),
		})
	end

	for _, patch in registry.patches do
		local pkgVersion = versionsByPackageName[patch.name]
		assert(pkgVersion ~= nil, `Solver did not resolve registry dependency '{patch.name}'`)
		patch.parentAliases[patch.alias] = `{patch.name}@{pkgVersion.versionString}`
	end
end

local function resolve(rootDirectory: string, universe: semver.Universe?, options: ResolveOptions?): lockfile.Lockfile
	local excludeDev = if options then options.excludeDev == true else false

	local queue: { manifest.DependencySpec } = {}
	local registry = createRegistryContext()

	local rootManifest = manifest.parseFile(rootDirectory)

	local dependencies = enqueueDependencies(
		queue,
		registry,
		rootManifest.package.dependencies,
		rootDirectory,
		rootDirectory,
		rootManifest.package.name
	)
	if not excludeDev then
		enqueueDependencies(
			queue,
			registry,
			rootManifest.package.devDependencies,
			rootDirectory,
			rootDirectory,
			rootManifest.package.name,
			dependencies
		)
	end

	local packages = processSpecQueue(queue, registry, rootDirectory)

	if next(registry.requirements) ~= nil then
		assert(universe ~= nil, "Registry dependencies require a universe to be provided")
		solveRegistryRequirements(packages, registry, universe)
	end

	for _, pkg in packages do
		if pkg.sourceKind ~= "registry" then
			table.freeze(pkg.dependencies)
		elseif not table.isfrozen(pkg.dependencies) then
			error("Registry package dependencies should be frozen")
		end
	end

	table.freeze(packages)
	table.freeze(dependencies)

	return table.freeze({
		version = 3,
		packages = packages,
		dependencies = dependencies,
	})
end

return {
	resolve = resolve,
}
