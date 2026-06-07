local lockfile = require("../lockfile")
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
		if pkg then
			for _ in pkg.dependencies do
				transitive += 1
			end
		end
		print(`  {key} ({pkg.sourceKind}, {transitive} dep(s))`)
	end
end

local function install()
	local rootDirectory = path.format(process.cwd())
	local lock = resolution.resolve(rootDirectory)
	printDiagnostics(lock)
	lockfile.writeLockfile(lock, rootDirectory)
end

return install
