local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local server = require("@lute/net/server")
local store = require("@commands/pkg/loom-core/src/store")

local temporaryDirectory = system.tmpdir()
local workingDirectory = path.join(temporaryDirectory, "lute-pkg")
local lutePath = path.format(process.execPath())

local function writeConfig(dir: path.Path, name: string, deps: string, registryUrl: string?)
	local registrySection = if registryUrl then `\n\tregistry = "{registryUrl}",` else ""
	fs.writeStringToFile(
		path.join(dir, "loom.config.luau"),
		`return \{\n\tpackage = \{\n\t\tname = "{name}",\n\t\tversion = "0.0.0",\n\t\tdependencies = \{{deps}\n\t\t},\n\t},{registrySection}\n}\n`
	)
end

local function run(cwd: path.Path): { exitcode: number, stdout: string, stderr: string }
	return process.run({ lutePath, "pkg", "install" }, { cwd = path.format(cwd) })
end

local function runWithEnv(
	cwd: path.Path,
	env: { [string]: string }
): { exitcode: number, stdout: string, stderr: string }
	return process.run({ lutePath, "pkg", "install" }, { cwd = path.format(cwd), env = env })
end

local function decodeBase64(encoded: string): string
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = {}
	local value = 0
	local bits = 0

	for index = 1, #encoded do
		local character = string.sub(encoded, index, index)
		if character == "=" then
			break
		end

		local alphabetIndex = string.find(alphabet, character, 1, true)
		assert(alphabetIndex ~= nil, `Invalid base64 character: {character}`)
		value = bit32.bor(bit32.lshift(value, 6), alphabetIndex - 1)
		bits += 6

		while bits >= 8 do
			bits -= 8
			table.insert(output, string.char(bit32.band(bit32.rshift(value, bits), 0xff)))
		end
	end

	return table.concat(output)
end

local archive = decodeBase64(
	"UEsDBAoAAAAAAEGBNV0AAAAAAAAAAAAAAAAEABwAc3JjL1VUCQADSrmxakq5sWp1eAsAAQT1AQAABBQAAABQSwMECgAAAAAAQYE1XQAAAAAAAAAAAAAAAA0AHABzcmMvaW5pdC5sdWF1VVQJAANKubFqSrmxanV4CwABBPUBAAAEFAAAAFBLAQIeAwoAAAAAAEGBNV0AAAAAAAAAAAAAAAAEABgAAAAAAAAAEADtQQAAAABzcmMvVVQFAANKubFqdXgLAAEE9QEAAAQUAAAAUEsBAh4DCgAAAAAAQYE1XQAAAAAAAAAAAAAAAA0AGAAAAAAAAAAAAKSBPgAAAHNyYy9pbml0Lmx1YXVVVAUAA0q5sWp1eAsAAQT1AQAABBQAAABQSwUGAAAAAAIAAgCdAAAAhQAAAAAA"
)

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
	end)

	suite:case("installsRegistryArchiveIntoQualifiedStoreAndSkipsExistingPackage", function(assert)
		local indexRequests = 0
		local contentUrlRequests = 0
		local archiveRequests = 0
		local instance: any
		instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				if req.path == "/api/v1/package-index/citrus" then
					indexRequests += 1
					return {
						status = 200,
						body = '[{"name":"citrus","version":"1.0.0","yanked":false,"dependencies":[]}]',
					}
				elseif req.path == "/api/v1/package-content-url/citrus/1.0.0" then
					contentUrlRequests += 1
					return {
						status = 200,
						body = `\{"contentUrl":"http://{instance.hostname}:{instance.port}/archive"\}`,
					}
				elseif req.path == "/archive" then
					archiveRequests += 1
					return { status = 200, body = archive }
				end

				return { status = 404, body = "not found" }
			end,
		})

		local registryUrl = `http://{instance.hostname}:{instance.port}`
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]],
			registryUrl
		)

		local homeDirectory = path.join(workingDirectory, "home")
		fs.createDirectory(homeDirectory)
		local env = setmetatable({
			HOME = path.format(homeDirectory),
			USERPROFILE = path.format(homeDirectory),
			LOOM_REGISTRY_TOKEN = "",
		}, { __index = process.env })

		local first = runWithEnv(workingDirectory, env)
		assert.eq(first.exitcode, 0)

		local storeKey = store.qualifyRegistryKey("citrus@1.0.0", registryUrl)
		local installedFile = path.join(homeDirectory, ".loom", "store", storeKey, "src", "init.luau")
		assert.that(fs.exists(installedFile))
		assert.eq(indexRequests, 1)
		assert.eq(contentUrlRequests, 1)
		assert.eq(archiveRequests, 1)

		local second = runWithEnv(workingDirectory, env)
		assert.eq(second.exitcode, 0)
		assert.eq(indexRequests, 1)
		assert.eq(contentUrlRequests, 1)
		assert.eq(archiveRequests, 1)

		instance.close()
	end)
end)
