local fs = require("@std/fs")
local git = require("./git")
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

local function findConflict(
	dependencies: { [string]: projectmanifest.DependencySpec },
	name: string,
	rev: string
): string?
	for existingKey, existingPkg in dependencies do
		if existingPkg.name == name and existingPkg.rev ~= rev then
			return existingKey
		end
	end
	return nil
end

local function checkForConflict(dependencies: { [string]: projectmanifest.DependencySpec }, spec: projectmanifest.DependencySpec): ()
	local conflictKey = findConflict(dependencies, spec.name, spec.rev)
	if conflictKey then
		error(
			`Version conflict for package '{spec.name}':\n`
				.. `  but {conflictKey} is already resolved\n`
				.. `Resolve by pinning both to the same revision.`
		)
	end
end

local function createLockFile(resolved: ResolvedGraph): lockfile.LockFile
	local deps: { [string]: lockfile.LockFilePackage } = {}

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

local function resolve(directory: string): ResolvedGraph
	local manifestPath = getManifestPath(directory)
	if not fs.exists(manifestPath) then
		error(`Manifest file not found: {manifestPath}`)
	end

	local queue: { projectmanifest.DependencySpec } = {}

	local packages: { string } = {}
	local dependencies: { [string]: projectmanifest.DependencySpec } = {}
	local graph: { [string]: { [string]: string } } = {}

	local rootManifest = projectmanifest.parseFile(manifestPath)
	for _, spec in rootManifest.package.dependencies do
		table.insert(queue, spec)
		table.insert(packages, getKey(spec))
	end

	table.freeze(packages)

	for _, spec in queue do
		local key = getKey(spec)

		-- Already resolved at this exact version — deduplicate
		if dependencies[key] then
			continue
		end

		-- Check for version conflict (same name, different rev)
		checkForConflict(dependencies, spec)

		-- New package — resolve it
		dependencies[key] = spec
		graph[key] = {}

		-- Download and install
		local installPath = getInstallPath(key)
		if spec.sourceKind == "github" then
			git.installPackage(spec, installPath)
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

	local lockfilePath = getLockfilePath(directory)
	local lf = createLockFile(resolved)
	fs.writeStringToFile(lockfilePath, `return {pp(lf)}\n`)

	return resolved
end

return {
	resolve = resolve,
}
