local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local path = require("@std/path")
local pp = require("@batteries/pp")
local projectmanifest = require("./projectmanifest")

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
		local sourcePath = `{rootDirectory}/Packages/{getKey(spec)}`
		github.installPackage(spec.source, spec.rev, sourcePath)
		return sourcePath
	else
		error(`Unsupported source kind: {spec.sourceKind} for package {spec.name}`)
	end
end

local function resolve(rootDirectory: string): lockfile.Lockfile
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
	local dependencies: { [string]: lockfile.LockfileDependency } = {}

	local rootManifest = projectmanifest.parseFile(rootManifestPath)
	for _, spec in rootManifest.package.dependencies do
		table.insert(packages, getKey(spec))
		table.insert(queue, spec)
	end

	table.freeze(packages)

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
			local memberManifest = projectmanifest.parseFile(memberManifestPath)
			local memberDeps: { [string]: string } = {}
			for depAlias, depSpec in memberManifest.package.dependencies do
				local normalized = normalizePathDependency(depSpec, memberDir, rootDirectory)
				memberDeps[depAlias] = getKey(normalized)
				table.insert(queue, normalized)
			end
			m[memberManifest.package.name] = table.freeze({
				path = memberPath,
				dependencies = table.freeze(memberDeps),
			})
		end
		members = table.freeze(m)
	end

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
		local transitiveDependencies: { [string]: string } = {}

		-- Download and install
		local installPath = fetchSource(spec, rootDirectory)

		-- Check for transitive dependencies
		local nestedManifestPath = getManifestPath(installPath)
		if fs.exists(nestedManifestPath) then
			local depManifest = projectmanifest.parseFile(nestedManifestPath)

			if depManifest.workspace ~= nil and spec.name ~= depManifest.package.name then
				local memberNames: { [string]: string } = {}

				for _, memberPath in depManifest.workspace do
					local memberDir = path.format(path.resolve(path.dirname(nestedManifestPath), memberPath))
					local memberManifestPath = getManifestPath(memberDir)
					if not fs.exists(memberManifestPath) then
						error(`Workspace member manifest not found: {memberManifestPath}`)
					end
					local memberManifest = projectmanifest.parseFile(memberManifestPath)

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

					for _, depSpec in memberManifest.package.dependencies do
						local normalized = normalizePathDependency(depSpec, memberDir, rootDirectory)
						table.insert(queue, normalized)
					end
				end

				if spec.name ~= depManifest.package.name and not memberNames[spec.name] then
					error(`Package '{spec.name}' not found in workspace at '{installPath}'`)
				end
			end

			for depAlias, depSpec in depManifest.package.dependencies do
				-- Normalize transitive path dep sources to be rootDirectory-relative
				local normalizedSpec = normalizePathDependency(depSpec, installPath, rootDirectory)
				transitiveDependencies[depAlias] = getKey(normalizedSpec)
				table.insert(queue, normalizedSpec)
			end
		end

		table.freeze(transitiveDependencies)

		dependencies[key] = table.freeze({
			name = spec.name,
			rev = spec.rev,
			source = spec.source,
			sourceKind = spec.sourceKind,
			installPath = path.format(path.relative(rootDirectory, installPath)),
			dependencies = transitiveDependencies,
		})
	end

	table.freeze(dependencies)

	local lf: lockfile.Lockfile = table.freeze({
		version = 2,
		packages = packages,
		members = members,
		dependencies = dependencies,
	})
	fs.writeStringToFile(lockfilePath, `return {pp(lf)}\n`)

	return lf
end

return {
	resolve = resolve,
}
