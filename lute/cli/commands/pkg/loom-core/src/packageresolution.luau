local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
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

local function getInstallPath(key: string): string
	return `Packages/_Index/{key}`
end

local function getKey(spec: projectmanifest.DependencySpec): string
	return `{spec.name}@{spec.rev}`
end

local function hasConflict(specA: projectmanifest.DependencySpec, specB: projectmanifest.DependencySpec): boolean
	return specA.rev ~= specB.rev or specA.source ~= specB.source or specA.sourceKind ~= specB.sourceKind
end

local function findConflict(
	spec: projectmanifest.DependencySpec,
	dependencies: { [string]: projectmanifest.DependencySpec },
	nameIndex: { [string]: string }
): string?
	local conflictKey = nameIndex[spec.name]
	if conflictKey and hasConflict(dependencies[conflictKey], spec) then
		return conflictKey
	end
	return nil
end

local function checkForConflict(
	spec: projectmanifest.DependencySpec,
	dependencies: { [string]: projectmanifest.DependencySpec },
	nameIndex: { [string]: string }
): ()
	local conflictKey = findConflict(spec, dependencies, nameIndex)
	if conflictKey then
		error(
			`Version conflict for package '{spec.name}':\n`
				.. `  but {conflictKey} is already resolved\n`
				.. `Resolve by pinning both to the same revision.`
		)
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
			installPath = getInstallPath(key),
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
	local rootInstallPath = `{rootDirectory}/{getInstallPath("")}`
	if fs.exists(rootInstallPath) then
		fs.remove(rootInstallPath)
	end

	local queue: { projectmanifest.DependencySpec } = {}

	local packages: { string } = {}
	local dependencies: { [string]: projectmanifest.DependencySpec } = {}
	local graph: { [string]: { [string]: string } } = {}

	local nameIndex: { [string]: string } = {}

	local rootManifest = projectmanifest.parseFile(rootManifestPath)
	for _, spec in rootManifest.package.dependencies do
		table.insert(packages, getKey(spec))
		table.insert(queue, spec)
	end

	table.freeze(packages)

	for _, spec in queue do
		-- Check for version conflict (same name, different rev)
		checkForConflict(spec, dependencies, nameIndex)

		local key = getKey(spec)
		if dependencies[key] then
			-- Already resolved at this exact version — deduplicate
			continue
		end

		-- New package — resolve it
		nameIndex[spec.name] = key
		dependencies[key] = spec
		graph[key] = {}

		-- Download and install
		local installPath = `{rootDirectory}/{getInstallPath(key)}`
		if spec.sourceKind == "github" then
			github.installPackage(spec, installPath)
		else
			error(`Unsupported source kind: {spec.sourceKind} for package {spec.name}`)
		end

		-- Check for transitive dependencies
		local nestedManifestPath = getManifestPath(installPath)
		if fs.exists(nestedManifestPath) then
			local depManifest = projectmanifest.parseFile(nestedManifestPath)
			for depAlias, depSpec in depManifest.package.dependencies do
				graph[key][depAlias] = getKey(depSpec)
				table.insert(queue, depSpec)
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
