local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local temporaryDirectory = system.tmpdir()
local workingDirectory = path.join(temporaryDirectory, "lute-pkg")
local lutePath = path.format(process.execPath())

local function writeConfig(dir: path.Path, name: string, deps: string)
	fs.writeStringToFile(
		path.join(dir, "loom.config.luau"),
		`return \{\n\tpackage = \{\n\t\tname = "{name}",\n\t\tversion = "0.0.0",\n\t\tdependencies = \{{deps}\n\t\t},\n\t},\n}\n`
	)
end

local function run(cwd: path.Path): { exitcode: number, stdout: string, stderr: string }
	return process.run({ lutePath, "pkg", "install" }, { cwd = path.format(cwd) })
end

test.suite("LutePkgInstall", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("failsWithoutManifest", function(assert)
		local result = run(workingDirectory)

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Manifest file not found")
	end)

	suite:case("succeedsWithNoDependencies", function(assert)
		writeConfig(workingDirectory, "root", "")

		local result = run(workingDirectory)

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Resolved 0 package(s).")
	end)

	suite:case("writesLockfile", function(assert)
		writeConfig(workingDirectory, "root", "")

		run(workingDirectory)

		assert.that(fs.exists(path.join(workingDirectory, "loom.lock.luau")))
	end)

	suite:case("installsSinglePathDependency", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(libDir, "lib", "")
		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]]
		)

		local result = run(workingDirectory)

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Resolved 1 package(s).")
		assert.strContains(result.stdout, "lib (path, 0 dep(s))")
	end)

	suite:case("installsMultiplePathDependencies", function(assert)
		for _, name in { "a", "b" } do
			local dir = path.join(workingDirectory, name)
			fs.createDirectory(dir)
			writeConfig(dir, name, "")
		end
		writeConfig(
			workingDirectory,
			"root",
			[[

			a = {
				sourceKind = "path",
				source = "./a",
			},
			b = {
				sourceKind = "path",
				source = "./b",
			},]]
		)

		local result = run(workingDirectory)

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Resolved 2 package(s).")
	end)

	suite:case("installsTransitivePathDependencies", function(assert)
		local libsDir = path.join(workingDirectory, "libs")
		fs.createDirectory(libsDir)

		local aDir = path.join(libsDir, "a")
		local bDir = path.join(libsDir, "b")
		fs.createDirectory(aDir)
		fs.createDirectory(bDir)

		writeConfig(bDir, "b", "")
		writeConfig(
			aDir,
			"a",
			[[

			b = {
				sourceKind = "path",
				source = "../b",
			},]]
		)
		writeConfig(
			workingDirectory,
			"root",
			[[

			a = {
				sourceKind = "path",
				source = "./libs/a",
			},]]
		)

		local result = run(workingDirectory)

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Resolved 1 package(s).")
		assert.strContains(result.stdout, "a (path, 1 dep(s))")

		local lockfile = fs.readFileToString(path.join(workingDirectory, "loom.lock.luau"))
		assert.strContains(lockfile, '"a"')
		assert.strContains(lockfile, '"b"')
	end)

	suite:case("lockfileRecordsSourceKindAndInstallPath", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(libDir, "lib", "")
		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]]
		)

		run(workingDirectory)

		local lockfile = fs.readFileToString(path.join(workingDirectory, "loom.lock.luau"))
		assert.strContains(lockfile, "version = 3")
		assert.strContains(lockfile, '"path"')
		assert.strContains(lockfile, "installPath")
	end)

	suite:case("failsWhenPathDependencyMissing", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			missing = {
				sourceKind = "path",
				source = "./does-not-exist",
			},]]
		)

		local result = run(workingDirectory)

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "does-not-exist")
	end)

	suite:case("reinstallIsIdempotent", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(libDir, "lib", "")
		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]]
		)

		local r1 = run(workingDirectory)
		local r2 = run(workingDirectory)

		assert.eq(r1.exitcode, 0)
		assert.eq(r2.exitcode, 0)
		assert.eq(r1.stdout, r2.stdout)
	end)
end)
