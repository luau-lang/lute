local resolution = require("../resolver/resolution")
local loom_types = require("../loom_types")
local project_manifest = require("../manifest/project_manifest")
local pp = require("../../extern/pp")

local fs_utils = require("../utils/fs_utils")
local luau = require("@std/luau")

local function executeLuauSource(source: string): any
	local bytecode = luau.compile(source)
	local func = luau.load(bytecode, "loom.config.luau", {})
	return func()
end

function install(package_source: loom_types.PackageSource)
	local manifestPath = "loom.config.luau"
	local manifestContent = fs_utils.readfiletostring(manifestPath)
	local manifestTable = executeLuauSource(manifestContent)
	local manifest = project_manifest.fromTable(manifestTable)

	local project_resolution = resolution.fromManifest(manifest)

	local lockfile = resolution.toLockFile(project_resolution)
	fs_utils.writestringtofile("loom.lock.luau", "return " .. pp(lockfile))

	for _, pkg in project_resolution.packages do
		print(`package: {pkg.name}, Rev: {pkg.rev}, Source: {pkg.source_kind} - {pkg.source}`)
		if pkg.source_kind == "git" then
			local zip_archive = package_source.git:downloadFromGitHubArchive(pkg.source)
			package_source.git:installZipArchive(pkg.name, pkg.rev, zip_archive)
		end
	end
end

return install
