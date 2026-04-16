local packageresolution = require("../packageresolution")
local path = require("@std/path")
local process = require("@std/process")

local function printDiagnostics(graph: packageresolution.ResolvedGraph)
	local depCount = 0
	for _ in graph.dependencies do
		depCount += 1
	end
	print(`Resolved {depCount} package(s).`)

	for key, pkg in graph.dependencies do
		local transitive = 0
		local deps = graph.graph[key]
		if deps then
			for _ in deps do
				transitive += 1
			end
		end
		print(`  {key} ({pkg.sourceKind}, {transitive} dep(s))`)
	end
end

local function install()
	local rootDirectory = path.format(process.cwd())
	local graph = packageresolution.resolve(rootDirectory)
	printDiagnostics(graph)
end

return install
