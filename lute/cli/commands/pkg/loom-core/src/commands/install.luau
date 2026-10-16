local cli = require("@batteries/cli")
local lockfile = require("../lockfile")
local registry = require("../registry")
local resolution = require("../resolution")
local path = require("@std/path")
local process = require("@std/process")
local store = require("../store")

local function printDiagnostics(lock: lockfile.Lockfile, includeDev: boolean)
	local devDependencies = if includeDev then lock.devDependencies or {} else {}
	local depCount = 0
	local devCount = 0
	for _ in lock.dependencies do
		depCount += 1
	end
	for _ in devDependencies do
		devCount += 1
	end

	if devCount > 0 then
		print(`Resolved {depCount + devCount} package(s) ({devCount} dev).`)
	else
		print(`Resolved {depCount} package(s).`)
	end

	local function printRoot(key: string, suffix: string)
		local transitive = 0
		local pkg = lock.packages[key]
		if pkg then
			for _ in pkg.dependencies do
				transitive += 1
			end
		end
		print(`  {key} ({pkg.sourceKind}, {transitive} dep(s)){suffix}`)
	end

	for _, key in lock.dependencies do
		printRoot(key, "")
	end
	for _, key in devDependencies do
		printRoot(key, " [dev]")
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
	local lock = resolution.resolve(rootDirectory, nil, {
		excludeDev = excludeDev,
		locked = locked,
	})
	local reachablePackages = lockfile.getReachablePackageKeys(lock, not excludeDev)

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

	printDiagnostics(lock, not excludeDev)
end

return install
