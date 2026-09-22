local cli = require("@batteries/cli")
local lockfile = require("../lockfile")
local registry = require("../registry")
local resolution = require("../resolution")
local path = require("@std/path")
local process = require("@std/process")
local store = require("../store")
local workspace = require("../workspace")

local function printDiagnostics(
	lock: lockfile.Lockfile,
	rootAliases: { [string]: { [string]: boolean } },
	devAliases: { [string]: { [string]: boolean } }
)
	local depCount = 0
	local devCount = 0
	for member, memberDependencies in lock.dependencies do
		local memberAliases = rootAliases[member]
		local memberDevAliases = devAliases[member]
		for alias in memberDependencies do
			if memberAliases and memberAliases[alias] then
				if memberDevAliases and memberDevAliases[alias] then
					devCount += 1
				else
					depCount += 1
				end
			end
		end
	end

	if devCount > 0 then
		print(`Resolved {depCount + devCount} package(s) ({devCount} dev).`)
	else
		print(`Resolved {depCount} package(s).`)
	end

	for member, memberDependencies in lock.dependencies do
		local memberAliases = rootAliases[member]
		local memberDevAliases = devAliases[member]
		for alias, key in memberDependencies do
			if not (memberAliases and memberAliases[alias]) then
				continue
			end
			local transitive = 0
			local pkg = lock.packages[key]
			if pkg then
				for _ in pkg.dependencies do
					transitive += 1
				end
			end
			local suffix = if memberDevAliases and memberDevAliases[alias] then " [dev]" else ""
			print(`  {member}:{alias} -> {key} ({pkg.sourceKind}, {transitive} dep(s)){suffix}`)
		end
	end
end

local function install(...: string)
	local args = cli.parser()
	args:add("exclude-dev", "flag", { help = "Skip dev dependencies" })
	args:add("locked", "flag", { help = "Error if lockfile doesn't match manifest (CI mode)" })

	local valid, err = pcall(cli.parse, args, { ... })
	if not valid then
		print(err)
		print(args:help())
		error(err)
	end

	local excludeDev = args:has("exclude-dev")
	local locked = args:has("locked")
	local startingDirectory = path.format(process.cwd())
	local rootDirectory, rootManifest = workspace.findRoot(startingDirectory)
	local rootWorkspace = workspace.resolve(rootDirectory, rootManifest)

	local devAliases: { [string]: { [string]: boolean } } = {}
	local rootAliases: { [string]: { [string]: boolean } } = {}
	for _, member in rootWorkspace.members do
		local memberAliases: { [string]: boolean } = {}
		rootAliases[member.name] = memberAliases
		for alias in member.package.dependencies do
			memberAliases[alias] = true
		end
		if not excludeDev then
			local memberDevAliases: { [string]: boolean } = {}
			devAliases[member.name] = memberDevAliases
			for alias in member.package.devDependencies do
				memberDevAliases[alias] = true
				memberAliases[alias] = true
			end
		end
	end

	local lock = resolution.resolve(rootWorkspace, nil, { excludeDev = excludeDev, locked = locked })
	local rootPackageKeys: { [string]: boolean } = {}
	for member, memberAliases in rootAliases do
		local memberDependencies = lock.dependencies[member]
		if memberDependencies then
			for alias in memberAliases do
				local key = memberDependencies[alias]
				if key then
					rootPackageKeys[key] = true
				end
			end
		end
	end
	local reachablePackages = lockfile.getReachablePackageKeys(lock, rootPackageKeys)

	for key, pkg in lock.packages do
		if reachablePackages[key] and pkg.sourceKind == "registry" and pkg.rev then
			store.ensureStoreDirectory()
			local registryUrl = pkg.registry
			assert(registryUrl ~= nil, `No registry URL for package '{pkg.name}'`)
			local storeKey = store.qualifyRegistryKey(key, registryUrl)
			if not store.hasPackage(storeKey) then
				registry.installPackage(registryUrl, pkg.source, pkg.rev, store.getPackagePath(storeKey))
			end
		end
	end

	printDiagnostics(lock, rootAliases, devAliases)
end

return install
