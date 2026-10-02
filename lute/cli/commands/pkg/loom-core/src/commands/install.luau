local cli = require("@batteries/cli")
local lockfile = require("../lockfile")
local resolution = require("../resolution")
local workspace = require("../workspace")
local path = require("@std/path")
local process = require("@std/process")

local function printDiagnostics(lock: lockfile.Lockfile, devAliases: { [string]: { [string]: boolean } })
	local depCount = 0
	local devCount = 0
	for member, dependencies in lock.dependencies do
		for alias in dependencies do
			if devAliases[member] and devAliases[member][alias] then
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

	for member, dependencies in lock.dependencies do
		for alias, key in dependencies do
			local transitive = 0
			local pkg = lock.packages[key]
			if pkg then
				for _ in pkg.dependencies do
					transitive += 1
				end
			end
			local suffix = if devAliases[member] and devAliases[member][alias] then " [dev]" else ""
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

	local excludeDev = args:get("exclude-dev") ~= nil
	local locked = args:get("locked") ~= nil
	local rootDirectory = path.format(process.cwd())
	local devAliases: { [string]: { [string]: boolean } } = {}
	local workspaceRoot, rootManifest = workspace.findRoot(rootDirectory)
	local resolvedWorkspace = workspace.resolve(workspaceRoot, rootManifest)
	for _, member in resolvedWorkspace.members do
		devAliases[member.name] = {}
		for _, depSpec in member.package.dependencies do
			if depSpec.sourceKind == "registry" then
				error("Registry dependencies are not yet supported by the install command")
			end
		end
		if not excludeDev then
			for alias, depSpec in member.package.devDependencies do
				if depSpec.sourceKind == "registry" then
					error("Registry dependencies are not yet supported by the install command")
				end
				devAliases[member.name][alias] = true
			end
		end
	end

	local lock = resolution.resolve(resolvedWorkspace, nil, { excludeDev = excludeDev, locked = locked })
	printDiagnostics(lock, devAliases)
end

return install
