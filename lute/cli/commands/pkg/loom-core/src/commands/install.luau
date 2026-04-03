local git = require("../packagesource/git")
local resolution = require("../resolver/resolution")
local projectManifest = require("../manifest/projectmanifest")
local pp = require("../../extern/pp")

local fsUtils = require("../utils/fsutils")
local luau = require("@std/luau")

local function executeLuauSource(source: string): any
	local bytecode = luau.compile(source)
	local func = luau.load(bytecode, "loom.config.luau", {})
	return func()
end

local function install()
	local manifestPath = "loom.config.luau"
	local manifestContent = fsUtils.readfiletostring(manifestPath)
	local manifestTable = executeLuauSource(manifestContent)
	local manifest = projectManifest.fromTable(manifestTable)

	local projectResolution = resolution.fromManifest(manifest)

	local lockfile = resolution.toLockFile(projectResolution)
	fsUtils.writestringtofile("loom.lock.luau", "return " .. pp(lockfile))

	for _, pkg in projectResolution.packages do
		print(`package: {pkg.name}, Rev: {pkg.rev}, Source: {pkg.sourceKind} - {pkg.source}`)
		if pkg.sourceKind == "github" then
			local zipArchive = git:downloadFromGitHubArchive(pkg.source)
			git:installZipArchive(pkg.name, pkg.rev, zipArchive)
		end
	end
end

return install
