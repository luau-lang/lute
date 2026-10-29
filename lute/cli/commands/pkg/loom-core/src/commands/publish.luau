local cli = require("@batteries/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local manifest = require("../manifest")
local publishManifest = require("../publish")
local publishArtifact = require("../publishartifact")
local registry = require("../registry")

local USAGE = "Usage: lute pkg publish [--dry-run | --list]"

local function publish(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("dry-run", "flag", { help = "Validate and build the package without uploading it" })
	args:add("list", "flag", { help = "Print files that would be included in the published package" })

	local valid, err = pcall(function(...: string)
		args:parse({ ... })
		local forwarded = args:forwarded() or {}
		assert(#forwarded == 0, `Unexpected argument: {forwarded[1]}`)
	end, ...)
	if not valid then
		print(USAGE)
		print(args:help())
		error(err, 0)
	end

	if args:has("help") then
		print(USAGE)
		print(args:help())
		return
	end

	local directory = path.format(process.cwd())
	local sourceManifestPath = path.format(path.join(directory, "loom.config.luau"))
	if not fs.exists(sourceManifestPath) then
		error("No package manifest found", 0)
	end
	local project = manifest.parseFile(sourceManifestPath)
	local package = project.package
	if args:has("list") then
		for _, name in
			publishArtifact.list(directory, sourceManifestPath, {
				contentRoot = package.contentRoot,
				files = package.files,
			})
		do
			print(name)
		end
		return
	end
	local generatedManifest = publishManifest.flattenPackage(package, project.registry)
	local archive = publishArtifact.build(directory, sourceManifestPath, generatedManifest, {
		contentRoot = package.contentRoot,
		files = package.files,
	})
	local identity = `{package.name :: string}@{package.version :: string}`
	print(`Built {identity} ({buffer.len(archive)} bytes).`)

	if args:has("dry-run") then
		print("Dry run complete. Package was not uploaded.")
		return
	end

	registry.publishPackage(project.registry, archive)
	print(`Published {identity}.`)
end

return publish
