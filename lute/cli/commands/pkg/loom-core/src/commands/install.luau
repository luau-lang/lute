local cli = require("@batteries/cli")
local lockfile = require("../lockfile")
local manifest = require("../manifest")
local resolution = require("../resolution")
local path = require("@std/path")
local process = require("@std/process")

local function printDiagnostics(lock: lockfile.Lockfile, devAliases: { [string]: boolean })
	local depCount = 0
	local devCount = 0
	for alias in lock.dependencies do
		if devAliases[alias] then
			devCount += 1
		else
			depCount += 1
		end
	end

	if devCount > 0 then
		print(`Resolved {depCount + devCount} package(s) ({devCount} dev).`)
	else
		print(`Resolved {depCount} package(s).`)
	end

	for alias, key in lock.dependencies do
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

local function install(...: string)
	local args = cli.parser()
	args:add("exclude-dev", "flag", { help = "Skip dev dependencies" })
	args:parse({ ... })

	local excludeDev = args:get("exclude-dev") ~= nil
	local rootDirectory = path.format(process.cwd())

	local rootManifest = manifest.parseFile(rootDirectory)
	local devAliases: { [string]: boolean } = {}

	for _, depSpec in rootManifest.package.dependencies do
		if depSpec.sourceKind == "registry" then
			error("Registry dependencies are not yet supported by the install command")
		end
	end
	if not excludeDev then
		for alias, depSpec in rootManifest.package.devDependencies do
			if depSpec.sourceKind == "registry" then
				error("Registry dependencies are not yet supported by the install command")
			end
			devAliases[alias] = true
		end
	end

	local lock = resolution.resolve(rootDirectory, nil, { excludeDev = excludeDev })
	printDiagnostics(lock, devAliases)
	lockfile.writeFile(lock, rootDirectory)
end

return install
