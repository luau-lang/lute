local fs = require("@std/fs")
local lockfile = require("./lockfile")
local path = require("@std/path")
local pp = require("@batteries/pp")
local manifest = require("./manifest")
local source = require("./source")
local store = require("./store")

local function getManifestPath(directory: string): string
	return `{directory}/loom.config.luau`
end

local function getLockfilePath(directory: string): string
	return `{directory}/loom.lock.luau`
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
		sourceKind = "path",
		source = path.format(path.relative(rootDirectory, sourcePath)),
	}) :: manifest.PathDependencySpec
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
		aliases[alias] = source.getKey(normalized)
		table.insert(queue, normalized)
	end
	return aliases
end

local function resolve(rootDirectory: string): lockfile.Lockfile
	local rootManifestPath = getManifestPath(rootDirectory)
	if not fs.exists(rootManifestPath) then
		error(`Manifest file not found: {rootManifestPath}`)
	end

	local lockfilePath = getLockfilePath(rootDirectory)

	local queue: { manifest.DependencySpec } = {}
	local packages: { [string]: lockfile.LockfileDependency } = {}
	local nameIndex: { [string]: string } = {}

	local rootManifest = manifest.parseFile(rootManifestPath)
	local dependencies = queueDependencies(queue, rootManifest.package.dependencies, rootDirectory, rootDirectory)
	table.freeze(dependencies)

	-- Seed workspace member dependencies into the shared queue
	local members: { [string]: lockfile.LockfileMember }? = nil
	if rootManifest.workspace ~= nil then
		local m: { [string]: lockfile.LockfileMember } = {}
		for _, memberPath in rootManifest.workspace do
			local memberDir = path.format(path.resolve(rootDirectory, memberPath))
			local memberManifestPath = getManifestPath(memberDir)
			if not fs.exists(memberManifestPath) then
				error(`Workspace member manifest not found: {memberManifestPath}`)
			end
			local memberManifest = manifest.parseFile(memberManifestPath)
			local memberName = memberManifest.package.name
			if m[memberName] then
				error(
					`Duplicate workspace member name '{memberName}':\n`
						.. `  {m[memberName].path}\n`
						.. `  {memberPath}`
				)
			end
			local memberDeps = queueDependencies(queue, memberManifest.package.dependencies, memberDir, rootDirectory)
			m[memberName] = table.freeze({
				path = memberPath,
				dependencies = table.freeze(memberDeps),
			})
			nameIndex[memberName] = memberName
		end
		members = table.freeze(m)
	end

	for _, spec in queue do
		local key = source.getKey(spec)

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
		local transitiveDependencies: { [string]: string } = {}

		-- Download and install
		local installPath = source.fetch(spec, rootDirectory)

		-- Check for transitive dependencies
		local nestedManifestPath = getManifestPath(installPath)
		if fs.exists(nestedManifestPath) then
			local depManifest = manifest.parseFile(nestedManifestPath)

			if depManifest.workspace ~= nil and spec.name ~= depManifest.package.name then
				local memberNames: { [string]: string } = {}

				for _, memberPath in depManifest.workspace do
					local memberDir = path.format(path.resolve(path.dirname(nestedManifestPath), memberPath))
					local memberManifestPath = getManifestPath(memberDir)
					if not fs.exists(memberManifestPath) then
						error(`Workspace member manifest not found: {memberManifestPath}`)
					end
					local memberManifest = manifest.parseFile(memberManifestPath)

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

			transitiveDependencies =
				queueDependencies(queue, depManifest.package.dependencies, installPath, rootDirectory)
		end

		table.freeze(transitiveDependencies)

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

	table.freeze(packages)

	local lock: lockfile.Lockfile = table.freeze({
		version = 3,
		members = members,
		packages = packages,
		dependencies = dependencies,
	})

	fs.writeStringToFile(lockfilePath, `return {pp(lock)}\n`)

	return lock
end

return {
	resolve = resolve,
}
