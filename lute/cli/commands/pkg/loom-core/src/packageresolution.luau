local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local path = require("@std/path")
local pp = require("@batteries/pp")
local projectmanifest = require("./projectmanifest")

export type ResolvedGraph = {
	read packages: { string },
	read dependencies: { [string]: projectmanifest.DependencySpec },
	read graph: { [string]: { [string]: string } },
}

local function getManifestPath(directory: string): string
	return `{directory}/loom.config.luau`
end

local function getLockfilePath(directory: string): string
	return `{directory}/loom.lock.luau`
end

local function getKey(spec: projectmanifest.DependencySpec): string
	if spec.rev ~= nil then
		return `{spec.name}@{spec.rev}`
	end
	return spec.name
end

local function getInstallPath(spec: projectmanifest.DependencySpec): string
	if spec.sourceKind == "path" then
		return spec.source
	end
	return `Packages/{getKey(spec)}`
end

local function hasConflict(specA: projectmanifest.DependencySpec, specB: projectmanifest.DependencySpec): boolean
	return specA.rev ~= specB.rev or specA.source ~= specB.source or specA.sourceKind ~= specB.sourceKind
end

local function normalizePathDependency(
	spec: projectmanifest.DependencySpec,
	installPath: string,
	rootDirectory: string
): projectmanifest.DependencySpec
	if spec.sourceKind == "path" then
		local sourcePath = path.format(path.resolve(installPath, spec.source))
		if not fs.exists(sourcePath) then
			error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
		end
		return table.freeze({
			name = spec.name,
			rev = spec.rev,
			source = path.format(path.relative(rootDirectory, sourcePath)),
			sourceKind = spec.sourceKind,
		})
	end
	return spec
end

local function fetchSource(spec: projectmanifest.DependencySpec, rootDirectory: string): string
	if spec.sourceKind == "path" then
		local sourcePath = path.format(path.resolve(rootDirectory, spec.source))
		if not fs.exists(sourcePath) then
			error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
		end
		return sourcePath
	elseif spec.sourceKind == "github" then
		assert(spec.rev ~= nil, `Expected rev to be non-nil for GitHub package '{spec.name}'`)
		local sourcePath = `{rootDirectory}/{getInstallPath(spec)}`
		github.installPackage(spec.source, spec.rev, sourcePath)
		return sourcePath
	else
		error(`Unsupported source kind: {spec.sourceKind} for package {spec.name}`)
	end
end

local function createLockfile(resolved: ResolvedGraph): lockfile.Lockfile
	local deps: { [string]: lockfile.LockfileDependency } = {}

	for key, pkg in resolved.dependencies do
		deps[key] = {
			name = pkg.name,
			rev = pkg.rev,
			source = pkg.source,
			sourceKind = pkg.sourceKind,
			installPath = getInstallPath(pkg),
			dependencies = resolved.graph[key] or {},
		}
	end

	return {
		version = 2,
		packages = resolved.packages,
		dependencies = deps,
	}
end

local function resolve(rootDirectory: string): ResolvedGraph
	local rootManifestPath = getManifestPath(rootDirectory)
	if not fs.exists(rootManifestPath) then
		error(`Manifest file not found: {rootManifestPath}`)
	end

	local lockfilePath = getLockfilePath(rootDirectory)
	-- TODO: read lockfile and diff against manifest to determine which packages need to be updated, deleted, etc.
	-- local lockfile = lockfile.parseFile(lockfilePath)
	-- for now, just clear the installation directory if it exists
	local rootInstallPath = `{rootDirectory}/Packages/`
	if fs.exists(rootInstallPath) then
		fs.removeDirectory(rootInstallPath, { recursive = true })
	end

	local queue: { projectmanifest.DependencySpec } = {}

	local packages: { string } = {}
	local dependencies: { [string]: projectmanifest.DependencySpec } = {}
	local graph: { [string]: { [string]: string } } = {}

	local rootManifest = projectmanifest.parseFile(rootManifestPath)
	for _, spec in rootManifest.package.dependencies do
		table.insert(packages, getKey(spec))
		table.insert(queue, spec)
	end

	table.freeze(packages)

	local nameIndex: { [string]: string } = {}

	for _, spec in queue do
		local key = getKey(spec)

		if dependencies[key] then
			if hasConflict(dependencies[key], spec) then
				error(
					`Source mismatch for package '{spec.name}':\n`
						.. `  resolved: {dependencies[key].source} ({dependencies[key].sourceKind})\n`
						.. `  incoming: {spec.source} ({spec.sourceKind})\n`
						.. `Both resolve to '{key}' but from different sources.`
				)
			else
				-- Already resolved at this exact version — deduplicate
				continue
			end
		end

		local conflictKey = nameIndex[spec.name]
		if conflictKey then
			error(
				`Version conflict for package '{spec.name}':\n`
					.. `  resolved: {conflictKey}\n`
					.. `  incoming: {key}\n`
					.. `Resolve by pinning both to the same revision.`
			)
		end

		-- New package — resolve it
		nameIndex[spec.name] = key
		dependencies[key] = spec
		graph[key] = {}

		-- Download and install
		local installPath = fetchSource(spec, rootDirectory)

		-- Check for transitive dependencies
		local nestedManifestPath = getManifestPath(installPath)
		if fs.exists(nestedManifestPath) then
			local depManifest = projectmanifest.parseFile(nestedManifestPath)
			for depAlias, depSpec in depManifest.package.dependencies do
				-- Normalize transitive path dep sources to be rootDirectory-relative
				local normalizedSpec = normalizePathDependency(depSpec, installPath, rootDirectory)
				graph[key][depAlias] = getKey(normalizedSpec)
				table.insert(queue, normalizedSpec)
			end
		end

		table.freeze(graph[key])
	end

	table.freeze(dependencies)
	table.freeze(graph)

	local resolved = table.freeze({
		packages = packages,
		dependencies = dependencies,
		graph = graph,
	})

	local lf = createLockfile(resolved)
	fs.writeStringToFile(lockfilePath, `return {pp(lf)}\n`)

	return resolved
end

return {
	resolve = resolve,
}
