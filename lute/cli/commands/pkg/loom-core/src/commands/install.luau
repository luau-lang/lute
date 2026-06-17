local fs = require("@std/fs")
local lockfile = require("../lockfile")
local manifest = require("../manifest")
local path = require("@std/path")
local process = require("@std/process")
local resolution = require("../resolution")

local function printDiagnostics(lock: lockfile.Lockfile)
	local depCount = 0
	for _ in lock.dependencies do
		depCount += 1
	end
	print(`Resolved {depCount} package(s).`)

	for _, key in lock.dependencies do
		local transitive = 0
		local pkg = lock.packages[key]
		for _ in pkg.dependencies do
			transitive += 1
		end
		print(`  {key} ({pkg.sourceKind}, {transitive} dep(s))`)
	end
end

local function install()
	local rootDirectory = path.format(process.cwd())
	local manifestPath = `{rootDirectory}/loom.config.luau`

	if fs.exists(manifestPath) then
		local rootManifest = manifest.parseFile(rootDirectory)
		for _, depSpec in rootManifest.package.dependencies do
			if depSpec.sourceKind == "registry" then
				error("Registry dependencies are not yet supported by the install command")
			end
		end
	end

	local lock = resolution.resolve(rootDirectory, nil)
	printDiagnostics(lock)
	lockfile.writeFile(lock, rootDirectory)
end

return install
