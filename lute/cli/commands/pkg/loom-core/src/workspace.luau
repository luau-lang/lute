local fs = require("@std/fs")
local glob = require("@batteries/glob")
local manifest = require("./manifest")
local path = require("@std/path")

export type Member = {
	read name: string,
	read directory: string,
	read manifest: manifest.ProjectManifest,
	read package: manifest.PackageManifest,
}

export type Workspace = {
	read rootDirectory: string,
	read rootManifest: manifest.ProjectManifest,
	read members: { Member },
	read overrides: { [string]: manifest.DependencySpec },
}

local function manifestPath(directory: string): string
	return path.format(path.join(directory, "loom.config.luau"))
end

local function formatDirectory(directory: path.Pathlike): string
	return path.format(path.resolve(directory))
end

local function addMember(
	members: { Member },
	names: { [string]: boolean },
	directory: string,
	projectManifest: manifest.ProjectManifest
)
	local pkg = projectManifest.package
	assert(pkg ~= nil, `Workspace member '{directory}' must declare a package`)
	assert(not names[pkg.name], `Duplicate workspace package name: '{pkg.name}'`)
	names[pkg.name] = true
	table.insert(
		members,
		table.freeze({ name = pkg.name, directory = directory, manifest = projectManifest, package = pkg })
	)
end

local function hasGlob(pattern: string): boolean
	return string.find(pattern, "[%*%?%[]") ~= nil
end

local function isWithinDirectory(directory: string, candidate: string): boolean
	local relative = path.relative(directory, candidate)
	return #relative.parts == 0 or relative.parts[1] ~= ".."
end

local function resolve(rootDirectory: string, rootManifest: manifest.ProjectManifest): Workspace
	rootDirectory = formatDirectory(rootDirectory)
	if rootManifest.workspace == nil then
		assert(rootManifest.package ~= nil, "A non-workspace manifest must declare a package")
		local rootMember: Member = table.freeze({
			name = rootManifest.package.name,
			directory = rootDirectory,
			manifest = rootManifest :: any,
			package = rootManifest.package,
		})
		return table.freeze({
			rootDirectory = rootDirectory,
			rootManifest = rootManifest,
			members = table.freeze({ rootMember }),
			overrides = rootManifest.overrides,
		})
	end

	local members: { Member } = {}
	local names: { [string]: boolean } = {}
	for _, memberPattern in rootManifest.workspace.members do
		local pattern = path.join(rootDirectory, memberPattern)
		local discoveredMembers = glob.discover(pattern)
		if not hasGlob(memberPattern) and #discoveredMembers == 0 then
			error(`Workspace member directory not found: {memberPattern}`)
		end
		for _, discovered in discoveredMembers do
			local directory = path.format(discovered)
			local configPath = manifestPath(directory)
			assert(fs.exists(configPath), `Workspace member '{directory}' has no loom.config.luau`)
			local memberManifest = manifest.parseFile(configPath)
			if directory ~= rootDirectory and next(memberManifest.overrides) ~= nil then
				print(`Warning: ignoring overrides in workspace member '{directory}'; overrides are workspace-scoped`)
			end
			addMember(members, names, directory, memberManifest)
		end
	end

	-- A root package belongs to its workspace even when it is not listed in members.
	if rootManifest.package ~= nil and not names[rootManifest.package.name] then
		addMember(members, names, rootDirectory, rootManifest)
	end

	if rootManifest.workspace.defaultMember ~= nil then
		assert(
			names[rootManifest.workspace.defaultMember],
			`Workspace default_member '{rootManifest.workspace.defaultMember}' is not a member`
		)
	end

	return table.freeze({
		rootDirectory = rootDirectory,
		rootManifest = rootManifest,
		members = table.freeze(members),
		overrides = rootManifest.overrides,
	})
end

local function findRoot(startDirectory: string): (string, manifest.ProjectManifest)
	local start = formatDirectory(startDirectory)
	local directory = start
	local singlePackageDirectory: string? = nil
	local singlePackageManifest: manifest.ProjectManifest? = nil
	while true do
		local configPath = manifestPath(directory)
		if fs.exists(configPath) then
			local projectManifest = manifest.parseFile(configPath)
			if projectManifest.workspace ~= nil then
				local workspace = resolve(directory, projectManifest)
				if directory == start then
					return directory, projectManifest
				end
				for _, member in workspace.members do
					if isWithinDirectory(member.directory, start) then
						return directory, projectManifest
					end
				end
			elseif projectManifest.package ~= nil and singlePackageDirectory == nil then
				singlePackageDirectory = directory
				singlePackageManifest = projectManifest
			end
		end

		local parent = path.dirname(directory)
		if parent == directory then
			break
		end
		directory = parent
	end
	if singlePackageDirectory ~= nil and singlePackageManifest ~= nil then
		return singlePackageDirectory, singlePackageManifest
	end
	error(`No package manifest found for: {startDirectory}`)
end

return {
	resolve = resolve,
	findRoot = findRoot,
}
