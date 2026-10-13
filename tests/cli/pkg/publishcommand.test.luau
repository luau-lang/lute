local fs = require("@std/fs")
local manifest = require("@commands/pkg/loom-core/src/manifest")
local path = require("@std/path")
local process = require("@std/process")
local publishArtifact = require("@commands/pkg/loom-core/src/publishartifact")
local publishManifest = require("@commands/pkg/loom-core/src/publish")
local server = require("@lute/net/server")
local system = require("@std/system")
local test = require("@std/test")
local unzip = require("@commands/pkg/loom-core/extern/unzip")

local workingDirectory = path.join(system.tmpdir(), `lute-pkg-publish-command-{process.pid()}`)
local lutePath = path.format(process.execPath())

local function writeFile(file: path.Path, contents: string)
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, contents)
end

local function writeManifest(directory: path.Path, contents: string)
	writeFile(path.join(directory, "loom.config.luau"), contents)
end

local function writePackage(directory: path.Path, name: string, version: string?)
	writeManifest(directory, `return \{ package = \{ name = "{name}", version = "{version or "1.2.3"}" \} \}`)
end

local function run(directory: path.Path, ...: string): process.ProcessResult
	return process.run({ lutePath, "pkg", "publish", ... }, {
		cwd = path.format(directory),
		env = setmetatable({ LOOM_ARTIFACTORY_TOKEN = "publish-command-test-token" }, { __index = process.env }),
	})
end

local function writeWorkspace(registryUrl: string?): path.Path
	local registryField = if registryUrl then `registry = "{registryUrl}",` else ""
	writeManifest(
		workingDirectory,
		string.format(
			[[return {
			workspace = { members = { "first", "second" } },
			version = "2.3.4",
			dependencies = {
				alias = { name = "vendor/library", sourceKind = "path", source = "../library", version = "^1.0.0" },
			},
			%s
		}]],
			registryField
		)
	)
	writePackage(path.join(workingDirectory, "first"), "first")
	local second = path.join(workingDirectory, "second")
	writeManifest(
		second,
		[[local root = require("../loom.config")
return {
	package = {
		name = "second",
		version = root.version,
		dependencies = root.dependencies,
		dev_dependencies = { dev = { sourceKind = "path", source = "../dev" } },
	},
}]]
	)
	return second
end

local function readEntry(reader: unzip.ZipReader, name: string): string
	local entry = reader:findEntry(name)
	assert(entry ~= nil, `Missing ZIP entry '{name}'`)
	return reader:extract(entry :: unzip.ZipEntry, { type = "text" }) :: string
end

test.suite("LutePkgPublish", function(suite)
	local closeServer: (() -> boolean)? = nil

	suite:beforeEach(function()
		fs.createDirectory(workingDirectory)
	end)

	suite:afterEach(function()
		if closeServer then
			closeServer()
			closeServer = nil
		end
		fs.removeDirectory(workingDirectory, { recursive = true })
	end)

	suite:case("showsHelpWithoutAManifest", function(assert)
		for _, flag in { "--help", "-h" } do
			local result = run(workingDirectory, flag)
			assert.eq(result.exitcode, 0)
			assert.strContains(result.stdout, "Usage: lute pkg publish [--package <member-name>] [--dry-run]")
		end
		local result = process.run({ lutePath, "pkg", "--help" })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "publish [--package <member-name>] [--dry-run]")
	end)

	suite:case("rejectsInvalidArgumentsBeforeLoadingAManifest", function(assert)
		for _, arguments in { { "--unknown" }, { "--package" }, { "extra" }, { "--", "extra" } } do
			local result = run(workingDirectory, table.unpack(arguments))
			assert.eq(result.exitcode, 1)
			assert.strContains(result.stderr, "argument")
			assert.strContains(result.stdout, "Usage: lute pkg publish")
		end
	end)

	suite:case("failsWithoutAManifest", function(assert)
		local result = run(workingDirectory, "--dry-run")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "No package manifest found")
	end)

	suite:case("dryRunBuildsStandaloneArchiveWithoutChangingPackageFiles", function(assert)
		writePackage(workingDirectory, "standalone")
		writeFile(path.join(workingDirectory, "init.luau"), "return 42\n")
		local configPath = path.join(workingDirectory, "loom.config.luau")
		local original = fs.readFileToString(configPath)
		local target = publishManifest.selectTarget(path.format(workingDirectory), nil)
		local archive = publishArtifact.build(target.directory, publishManifest.flattenPackage(target.package))

		local result = run(workingDirectory, "--dry-run")
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Built standalone@1.2.3 ({buffer.len(archive)} bytes).`)
		assert.strContains(result.stdout, "Dry run complete. Package was not uploaded.")
		assert.eq(fs.readFileToString(configPath), original)
		assert.eq(#fs.listDirectory(workingDirectory), 2)
	end)

	suite:case("selectsWorkspaceMembersByNameOrCurrentDirectory", function(assert)
		local second = writeWorkspace(nil)
		local ambiguous = run(workingDirectory, "--dry-run")
		assert.eq(ambiguous.exitcode, 1)
		assert.strContains(ambiguous.stderr, "Use --package <member-name>")

		local missing = run(workingDirectory, "--package", "missing", "--dry-run")
		assert.eq(missing.exitcode, 1)
		assert.strContains(missing.stderr, "Workspace has no package named 'missing'")

		local selected = run(workingDirectory, "--package", "second", "--dry-run")
		assert.eq(selected.exitcode, 0)
		assert.strContains(selected.stdout, "Built second@2.3.4")

		local nested = path.join(second, "src")
		fs.createDirectory(nested)
		local implicit = run(nested, "--dry-run")
		assert.eq(implicit.exitcode, 0)
		assert.strContains(implicit.stdout, "Built second@2.3.4")
	end)

	suite:case("rejectsInvalidPackageVersionsInDryRun", function(assert)
		writePackage(workingDirectory, "invalid", "1.2")
		local result = run(workingDirectory, "--dry-run")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Invalid package version")
	end)

	suite:case("rejectsUnpublishableProductionDependenciesInDryRun", function(assert)
		for _, dependency in
			{
				'{ sourceKind = "path", source = "../local" }',
				'{ sourceKind = "github", source = "owner/repo", rev = "main" }',
				'{ sourceKind = "registry", source = "library", version = "invalid" }',
			}
		do
			writeManifest(
				workingDirectory,
				`return \{ package = \{ name = "invalid", version = "1.0.0", dependencies = \{ library = {dependency} \} \} \}`
			)
			local result = run(workingDirectory, "--dry-run")
			assert.eq(result.exitcode, 1)
			assert.strContains(result.stderr, "version")
		end
	end)

	suite:case("uploadRequiresARegistry", function(assert)
		writePackage(workingDirectory, "standalone")
		local result = run(workingDirectory)
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "No registry configured for publishing")
	end)

	suite:case("uploadsOnlyTheSelectedPackageWithAnEvaluatedManifest", function(assert)
		local requests: { server.ReceivedRequest } = {}
		local instance = server.serve({
			port = 0,
			handler = function(request: server.ReceivedRequest): server.ServerResponse
				table.insert(requests, request)
				return { status = 201, body = "{}" }
			end,
		})
		closeServer = instance.close
		local second = writeWorkspace(`http://{instance.hostname}:{instance.port}`)
		writeFile(path.join(second, "src", "init.luau"), "return 42\n")
		writeFile(path.join(second, "loom.lock.luau"), "return {}\n")
		writeFile(path.join(workingDirectory, "first", "sibling.luau"), "return 0\n")
		local original = fs.readFileToString(path.join(second, "loom.config.luau"))

		local dryRun = run(workingDirectory, "--dry-run", "--package", "second")
		assert.eq(dryRun.exitcode, 0)
		assert.eq(#requests, 0)

		local result = run(workingDirectory, "--package", "second")
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Published second@2.3.4.")
		assert.eq(#requests, 1)
		local request = requests[1]
		assert.eq(request.method, "POST")
		assert.eq(request.path, "/api/v1/publish")
		assert.eq(request.headers["content-type"], "application/zip")
		assert.eq(request.headers["artifactory-token"], "publish-command-test-token")

		local reader = unzip.load(buffer.fromstring(request.body))
		assert.eq(reader:getStats().fileCount, 2)
		assert.eq(readEntry(reader, "src/init.luau"), "return 42\n")
		local generatedPath = path.join(workingDirectory, "generated.luau")
		writeFile(generatedPath, readEntry(reader, "loom.config.luau"))
		local generated = manifest.parseFile(path.format(generatedPath))
		local package = generated.package :: manifest.PackageManifest
		assert.eq(package.name, "second")
		assert.eq(package.version, "2.3.4")
		assert.eq(package.dependencies.alias.sourceKind, "registry")
		assert.eq(package.dependencies.alias.source, "vendor/library")
		assert.eq(package.dependencies.alias.version, "^1.0.0")
		assert.eq(package.devDependencies.dev.sourceKind, "path")
		assert.eq(generated.registry, nil)
		assert.eq(generated.workspace, nil)
		assert.eq(fs.readFileToString(path.join(second, "loom.config.luau")), original)
	end)

	suite:case("reportsUploadFailureWithoutPrintingSuccess", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(): server.ServerResponse
				return { status = 409, body = "duplicate version" }
			end,
		})
		closeServer = instance.close
		writeManifest(
			workingDirectory,
			`return \{ package = \{ name = "duplicate", version = "1.0.0" \}, registry = "http://{instance.hostname}:{instance.port}" \}`
		)
		local result = run(workingDirectory)
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Package version already exists")
		assert.eq(string.find(result.stdout, "Published", 1, true), nil)
	end)
end)
