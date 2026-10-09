local cli = require("@batteries/cli")
local path = require("@std/path")
local process = require("@std/process")
local publishManifest = require("../publish")
local publishArtifact = require("../publishartifact")
local registry = require("../registry")

local USAGE = "Usage: lute pkg publish [--package <member-name>] [--dry-run]"

local function publish(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("package", "option", { help = "Workspace package name to publish" })
	args:add("dry-run", "flag", { help = "Validate and build the package without uploading it" })

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

	local target = publishManifest.selectTarget(path.format(process.cwd()), args:get("package"))
	local generatedManifest = publishManifest.flattenPackage(target.package)
	local archive = publishArtifact.build(target.directory, generatedManifest)
	local identity = `{target.package.name}@{target.package.version}`
	print(`Built {identity} ({buffer.len(archive)} bytes).`)

	if args:has("dry-run") then
		print("Dry run complete. Package was not uploaded.")
		return
	end

	registry.publishPackage(target.workspace.registry, archive)
	print(`Published {identity}.`)
end

return publish
