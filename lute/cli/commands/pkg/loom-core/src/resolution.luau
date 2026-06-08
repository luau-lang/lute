local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local manifest = require("./manifest")
local path = require("@std/path")
local store = require("./store")

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
	contextDir: string,
	rootDirectory: string
): manifest.DependencySpec
	-- normalization is a no-op if it's not a path dependency
	if spec.sourceKind ~= "path" then
		return spec
	end

	local sourcePath = path.format(path.resolve(contextDir, spec.source))
	if not fs.exists(sourcePath) then
		error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
	end

	return table.freeze({
		name = spec.name,
		sourceKind = "path" :: "path",
		source = path.format(path.relative(rootDirectory, sourcePath)),
	})
end

local function enqueueDependencies(
	queue: { manifest.DependencySpec },
	deps: { [string]: manifest.DependencySpec },
	contextDir: string,
	rootDirectory: string
): { [string]: string }
	local aliases: { [string]: string } = {}
	for alias, depSpec in deps do
		local normalized = normalizePathDependency(depSpec, contextDir, rootDirectory)
		aliases[alias] = getKey(normalized)
		table.insert(queue, normalized)
	end
	return table.freeze(aliases)
end

local function seedWorkspaceMembers(
	queue: { manifest.DependencySpec },
	nameIndex: { [string]: string },
	rootDirectory: string,
	rootManifest: manifest.ProjectManifest
): { [string]: lockfile.LockfileMember }?
	if rootManifest.workspace == nil then
		return nil
	end
	local members: { [string]: lockfile.LockfileMember } = {}
	for _, memberPath in rootManifest.workspace do
		local memberDir = path.format(path.resolve(rootDirectory, memberPath))
		local memberManifest = manifest.parseManifest(memberDir)
		local memberName = memberManifest.package.name
		if members[memberName] then
			error(
				`Duplicate workspace member name '{memberName}':\n`
					.. `  {members[memberName].path}\n`
					.. `  {memberPath}`
			)
		end
		local memberDeps = enqueueDependencies(queue, memberManifest.package.dependencies, memberDir, rootDirectory)
		members[memberName] = table.freeze({
			path = memberPath,
			dependencies = memberDeps,
		})
		nameIndex[memberName] = memberName
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
	nameIndex: { [string]: string }
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

	local conflictKey = nameIndex[spec.name]
	if conflictKey then
		error(
			`Version conflict for package '{spec.name}':\n`
				.. `  resolved: {conflictKey}\n`
				.. `  incoming: {key}\n`
				.. `Resolve by pinning both to the same revision.`
		)
	end

	-- new dependency
	nameIndex[spec.name] = key
	return false
end

local function processSpecQueue(
	queue: { manifest.DependencySpec },
	nameIndex: { [string]: string },
	rootDirectory: string
): { [string]: lockfile.LockfileDependency }
	local packages: { [string]: lockfile.LockfileDependency } = {}

	for _, spec in queue do
		local key = getKey(spec)
		if shouldDeduplicate(key, spec, packages, nameIndex) then
			continue
		end

		local installPath = fetchSource(spec, rootDirectory)
		local depManifest = manifest.parseManifest(installPath)
		local transitiveDependencies =
			enqueueDependencies(queue, depManifest.package.dependencies, installPath, rootDirectory)

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

	-- "destory" queue
	table.clear(queue)
	table.freeze(queue)

	return table.freeze(packages)
end

local function resolve(rootDirectory: string): lockfile.Lockfile
	local queue: { manifest.DependencySpec } = {}
	local nameIndex: { [string]: string } = {}

	local rootManifest = manifest.parseManifest(rootDirectory)

	local dependencies = enqueueDependencies(queue, rootManifest.package.dependencies, rootDirectory, rootDirectory)
	local members = seedWorkspaceMembers(queue, nameIndex, rootDirectory, rootManifest)
	local packages = processSpecQueue(queue, nameIndex, rootDirectory)

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
