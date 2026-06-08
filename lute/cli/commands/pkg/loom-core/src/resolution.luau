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

local function queueDependencies(
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

-- Builds the lockfile members map and queues each member's deps onto the shared
-- queue. Returns nil if the project has no workspace declaration. Members are
-- registered in nameIndex so a member and a path dep can't both claim the same
-- name without the main loop catching it.
local function seedWorkspaceMembers(
	rootManifest: manifest.ProjectManifest,
	rootDirectory: string,
	queue: { manifest.DependencySpec },
	nameIndex: { [string]: string }
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
		local memberDeps = queueDependencies(queue, memberManifest.package.dependencies, memberDir, rootDirectory)
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

local function processWorkspaceMembers(depManifest: manifest.ProjectManifest, nestedManifestPath: string, installPath: string, rootDirectory: string, spec: manifest.DependencySpec, queue: { manifest.DependencySpec })
	if depManifest.workspace ~= nil and spec.name ~= depManifest.package.name then
		local memberNames: { [string]: string } = {}

		for _, memberPath in depManifest.workspace do
			local memberDir = path.format(path.resolve(path.dirname(nestedManifestPath), memberPath))
			local memberManifest = manifest.parseManifest(memberDir)

			local memberName = memberManifest.package.name
			if memberNames[memberName] then
				error(
					`Duplicate workspace member name '{memberName}':\n`
						.. `  {memberNames[memberName]}\n`
						.. `  {memberPath}`
				)
			end
			memberNames[memberName] = memberPath

			-- resolve to the member package
			if spec.name == memberName then
				installPath = memberDir
				depManifest = memberManifest
			end

			queueDependencies(queue, memberManifest.package.dependencies, memberDir, rootDirectory)
		end

		if spec.name ~= depManifest.package.name and not memberNames[spec.name] then
			error(`Package '{spec.name}' not found in workspace at '{installPath}'`)
		end
	end
end

-- Fetches a spec's source, parses any nested manifest, and queues its transitive
-- deps. Returns the (possibly redirected, when a github source turns out to be a
-- workspace whose member we wanted) install path and the frozen alias→key map
-- of transitive deps queued.
local function processSpec(
	spec: manifest.DependencySpec,
	queue: { manifest.DependencySpec },
	rootDirectory: string
): (string, { [string]: string })
	local installPath = fetchSource(spec, rootDirectory)
	local nestedManifestPath = manifest.resolveManifestPath(installPath)
	if not fs.exists(nestedManifestPath) then
		return installPath, table.freeze({} :: { [string]: string })
	end

	local depManifest = manifest.parseManifest(nestedManifestPath)
	processWorkspaceMembers(depManifest, nestedManifestPath, installPath, rootDirectory, spec, queue)
	local transitiveDependencies = queueDependencies(queue, depManifest.package.dependencies, installPath, rootDirectory)
	return installPath, transitiveDependencies
end

local function makeLockfileDependency(
	spec: manifest.DependencySpec,
	installPath: string,
	rootDirectory: string,
	transitiveDependencies: { [string]: string }
): lockfile.LockfileDependency
	return table.freeze({
		name = spec.name,
		rev = if spec.sourceKind == "github" then spec.rev else nil,
		source = spec.source,
		sourceKind = spec.sourceKind,
		installPath = if spec.sourceKind == "path"
			then path.format(path.relative(rootDirectory, installPath))
			else store.toStorePath(getKey(spec)),
		dependencies = transitiveDependencies,
	})
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

local function resolve(rootDirectory: string): lockfile.Lockfile
	local queue: { manifest.DependencySpec } = {}
	local packages: { [string]: lockfile.LockfileDependency } = {}
	local nameIndex: { [string]: string } = {}

	local rootManifest = manifest.parseManifest(rootDirectory)
	local dependencies = queueDependencies(queue, rootManifest.package.dependencies, rootDirectory, rootDirectory)
	local members = seedWorkspaceMembers(rootManifest, rootDirectory, queue, nameIndex)

	for _, spec in queue do
		local key = getKey(spec)
		if shouldDeduplicate(key, spec, packages, nameIndex) then
			continue
		end
		local installPath, transitiveDependencies = processSpec(spec, queue, rootDirectory)
		packages[key] = makeLockfileDependency(spec, installPath, rootDirectory, transitiveDependencies)
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
