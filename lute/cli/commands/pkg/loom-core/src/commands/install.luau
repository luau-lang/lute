local cli = require("@batteries/cli")
local fs = require("@std/fs")
local lockfile = require("../lockfile")
local manifest = require("../manifest")
local registry = require("../registry")
local resolution = require("../resolution")
local path = require("@std/path")
local process = require("@std/process")
local store = require("../store")

local function printDiagnostics(
	lock: lockfile.Lockfile,
	rootAliases: { [string]: boolean },
	devAliases: { [string]: boolean }
)
	local depCount = 0
	local devCount = 0
	for alias in lock.dependencies do
		if rootAliases[alias] then
			if devAliases[alias] then
				devCount += 1
			else
				depCount += 1
			end
		end
	end

	if devCount > 0 then
		print(`Resolved {depCount + devCount} package(s) ({devCount} dev).`)
	else
		print(`Resolved {depCount} package(s).`)
	end

	for alias, key in lock.dependencies do
		if rootAliases[alias] then
			local transitive = 0
			local pkg = lock.packages[key]
			if pkg then
				for _ in pkg.dependencies do
					transitive += 1
				end
			end
			local suffix = if devAliases[alias] then " [dev]" else ""
			print(`  {key} ({pkg.sourceKind}, {transitive} dep(s)){suffix}`)
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

	local excludeDev = args:get("exclude-dev") ~= nil
	local locked = args:get("locked") ~= nil
	local rootDirectory = path.format(process.cwd())
	local manifestPath = `{rootDirectory}/loom.config.luau`

	local devAliases: { [string]: boolean } = {}
	local rootAliases: { [string]: boolean } = {}

	if fs.exists(manifestPath) then
		local rootManifest = manifest.parseFile(manifestPath)
		for alias in rootManifest.package.dependencies do
			rootAliases[alias] = true
		end
		if not excludeDev then
			for alias in rootManifest.package.devDependencies do
				devAliases[alias] = true
				rootAliases[alias] = true
			end
		end
	end

	local lock = resolution.resolve(rootDirectory, nil, { excludeDev = excludeDev, locked = locked })
	local reachablePackages = lockfile.getReachablePackageKeys(lock, rootAliases)

	for key, pkg in lock.packages do
		if reachablePackages[key] and pkg.sourceKind == "registry" and pkg.rev then
			store.ensureStoreDirectory()
			local registryUrl = pkg.registry
			assert(registryUrl ~= nil, `No registry URL for package '{pkg.name}'`)
			local storeKey = store.getRegistryPackageKey(key, registryUrl)
			if not store.hasPackage(storeKey) then
				registry.installPackage(registryUrl, pkg.source, pkg.rev, store.getPackagePath(storeKey))
			end
		end
	end

	printDiagnostics(lock, rootAliases, devAliases)
end

return install
