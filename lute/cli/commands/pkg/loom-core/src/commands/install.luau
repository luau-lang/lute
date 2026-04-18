local lockfile = require("../lockfile")
local packageresolution = require("../packageresolution")
local path = require("@std/path")
local process = require("@std/process")

local function printDiagnostics(lockfile: lockfile.Lockfile)
	local depCount = 0
	for _ in lockfile.packages do
		depCount += 1
	end
	print(`Resolved {depCount} package(s).`)

	for key, pkg in lockfile.dependencies do
		local transitive = 0
		for _ in pkg.dependencies do
			transitive += 1
		end
		print(`  {key} ({pkg.sourceKind}, {transitive} dep(s))`)
	end
end

local function install()
	local rootDirectory = path.format(process.cwd())
	local lockfile = packageresolution.resolve(rootDirectory)
	printDiagnostics(lockfile)
end

return install
