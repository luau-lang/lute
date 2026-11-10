local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local server = require("@lute/net/server")
local store = require("@commands/pkg/loom-core/src/store")
local system = require("@std/system")
local test = require("@std/test")
local vendor = require("@commands/pkg/loom-core/src/vendor")
local zipWriter = require("@commands/pkg/loom-core/src/zipwriter")

local workingDirectory = path.join(system.tmpdir(), `lute-pkg-vendor-{process.pid()}`)
local homeDirectory = path.join(workingDirectory, "home")
local projectDirectory = path.join(workingDirectory, "project")
local lutePath = path.format(process.execPath())

local env = setmetatable({
	HOME = path.format(homeDirectory),
	USERPROFILE = path.format(homeDirectory),
}, { __index = process.env })

local function writeFile(file: path.Path, contents: string)
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, contents)
end

local function writeManifest(directory: path.Path, contents: string)
	writeFile(path.join(directory, "pkg.luau"), contents)
end

local function run(...: string): process.ProcessResult
	return process.run({ lutePath, "pkg", "install", ... }, { cwd = path.format(projectDirectory), env = env })
end

local function vendored(...: string): path.Path
	return path.join(projectDirectory, ".lpm", ...)
end

local citrusArchive = buffer.tostring(zipWriter.write({
	{ name = "init.luau", contents = buffer.fromstring("return 'citrus'\n") },
	{
		name = "pkg.luau",
		contents = buffer.fromstring('return { package = { name = "citrus", version = "1.0.0" } }\n'),
	},
}))

-- Serves citrus@1.0.0. Returns the server and its registry URL.
local function serveCitrus(): (any, string)
	local instance: any
	instance = server.serve({
		port = 0,
		handler = function(req: server.ReceivedRequest): server.ServerResponse
			if req.path == "/api/v1/package-index/citrus" then
				return {
					status = 200,
					body = '[{"name":"citrus","version":"1.0.0","yanked":false,"dependencies":[]}]',
				}
			elseif req.path == "/api/v1/package-content-url/citrus/1.0.0" then
				return {
					status = 200,
					body = `\{"contentUrl":"http://{instance.hostname}:{instance.port}/archive"\}`,
				}
			elseif req.path == "/archive" then
				return { status = 200, body = citrusArchive }
			end
			return { status = 404, body = "not found" }
		end,
	})
	return instance, `http://{instance.hostname}:{instance.port}`
end

-- A root package that depends on citrus, plus any extra dependency entries.
local function writeCitrusProject(registryUrl: string, section: "dependencies" | "devDependencies", extra: string?)
	local citrus = 'citrus = { sourceKind = "registry", source = "citrus", version = "^1.0.0" },'
	local dependencies = (extra or "") .. if section == "dependencies" then citrus else ""
	local devDependencies = if section == "devDependencies" then citrus else ""
	writeManifest(
		projectDirectory,
		string.format(
			[[return {
	registry = %q,
	package = {
		name = "root",
		version = "0.0.0",
		dependencies = { %s },
		devDependencies = { %s },
	},
}
]],
			registryUrl,
			dependencies,
			devDependencies
		)
	)
end

test.suite("LutePkgInstallVendor", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(homeDirectory, { makeParents = true })
		fs.createDirectory(projectDirectory, { makeParents = true })
	end)

	suite:afterAll(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
	end)

	suite:case("encodesLockKeysAsSingleDirectoryNames", function(assert)
		assert.eq(vendor.encodeKey("citrus@1.2.3"), "citrus@1.2.3")
		assert.eq(vendor.encodeKey("apple@feature/x"), "apple@feature%2Fx")
		assert.eq(vendor.encodeKey("a b%"), "a%20b%25")
		assert.throws(function()
			vendor.encodeKey("")
		end)
	end)

	suite:case("vendorsRegistryArchiveWhole", function(assert)
		local instance, registryUrl = serveCitrus()
		writeCitrusProject(registryUrl, "dependencies")

		local result = run("--vendor")
		instance.close()

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Vendored 1 package(s) into .lpm.")
		assert.eq(fs.readFileToString(vendored("citrus@1.0.0", "init.luau")), "return 'citrus'\n")
		assert.that(fs.exists(vendored("citrus@1.0.0", "pkg.luau")))
	end)

	suite:case("leavesWorkspaceMembersInPlaceAndVendorsTheirDependencies", function(assert)
		local instance, registryUrl = serveCitrus()
		writeManifest(
			projectDirectory,
			string.format(
				[[return {
	registry = %q,
	package = { dependencies = {
		apple = { sourceKind = "path", source = "./modules/apple" },
		banana = { sourceKind = "path", source = "./modules/banana" },
	} },
}
]],
				registryUrl
			)
		)
		local apple = path.join(projectDirectory, "modules", "apple")
		writeManifest(
			apple,
			string.format(
				[[return { registry = %q, package = { name = "apple", version = "1.0.0", content_root = "src", dependencies = {
	citrus = { sourceKind = "registry", source = "citrus", version = "^1.0.0" },
} } }
]],
				registryUrl
			)
		)
		writeFile(path.join(apple, "src", "init.luau"), "return require('@citrus')\n")
		local banana = path.join(projectDirectory, "modules", "banana")
		writeManifest(banana, 'return { package = { name = "banana", version = "1.0.0" } }')
		writeFile(path.join(banana, "init.luau"), "return 'banana'\n")

		local result = run("--vendor")
		instance.close()

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Vendored 1 package(s) into .lpm; 2 path package(s) stay in place.")
		assert.that(fs.exists(vendored("citrus@1.0.0", "init.luau")))
		assert.that(not fs.exists(vendored("apple")))
		assert.that(not fs.exists(vendored("banana")))
	end)

	suite:case("revendoringPrunesStaleEntriesAndFiles", function(assert)
		local instance, registryUrl = serveCitrus()
		writeCitrusProject(registryUrl, "dependencies")
		assert.eq(run("--vendor").exitcode, 0)

		writeFile(vendored("shared", "init.luau"), "return {}\n")
		writeFile(vendored("citrus@1.0.0", "nested", "stale.luau"), "return {}\n")
		local result = run("--vendor")
		instance.close()

		assert.eq(result.exitcode, 0)
		assert.that(not fs.exists(vendored("shared")))
		assert.that(not fs.exists(vendored("citrus@1.0.0", "nested")))
		assert.eq(fs.readFileToString(vendored("citrus@1.0.0", "init.luau")), "return 'citrus'\n")
	end)

	suite:case("excludeDevSkipsDevDependencies", function(assert)
		local instance, registryUrl = serveCitrus()
		writeCitrusProject(registryUrl, "devDependencies")

		local result = run("--vendor", "--exclude-dev")
		instance.close()

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Vendored 0 package(s) into .lpm.")
		assert.that(not fs.exists(vendored("citrus@1.0.0")))
	end)

	suite:case("normalInstallDoesNotTouchVendorDirectory", function(assert)
		local instance, registryUrl = serveCitrus()
		writeCitrusProject(registryUrl, "dependencies")
		writeFile(vendored("sentinel.luau"), "return 'preserved'\n")

		local result = run()
		instance.close()

		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(vendored("sentinel.luau")), "return 'preserved'\n")
	end)

	suite:case("vendorsGitHubTargetContentRootIntoItsOwnEntry", function(assert)
		local source = "https://github.com/owner/fruits"
		local rev = "feature/x"
		local checkout = path.join(homeDirectory, ".loom", "store", store.getGitHubCheckoutKey(source, rev))
		local apple = path.join(checkout, "modules", "apple")
		writeManifest(checkout, "return { package = {} }")
		writeManifest(apple, 'return { package = { name = "apple", version = "1.0.0", content_root = "src" } }')
		writeFile(path.join(apple, "src", "init.luau"), "return 'apple'\n")
		writeFile(path.join(apple, "tests", "apple.test.luau"), "-- outside content_root\n")
		writeFile(path.join(checkout, "modules", "banana", "init.luau"), "return 'banana'\n")

		writeManifest(
			projectDirectory,
			string.format(
				[[return { package = { name = "root", version = "0.0.0", dependencies = {
	apple = { sourceKind = "github", source = %q, rev = %q, target = "modules/apple" },
} } }
]],
				source,
				rev
			)
		)
		writeFile(
			path.join(projectDirectory, "pkg.lock.luau"),
			string.format(
				[[return {
	version = 4,
	packages = {
		[%q] = {
			name = "apple",
			rev = %q,
			source = %q,
			sourceKind = "github",
			target = "modules/apple",
			installPath = %q,
			dependencies = {},
		},
	},
	dependencies = { apple = %q },
}
]],
				`apple@{rev}`,
				rev,
				source,
				store.getGitHubInstallPath(source, rev, "modules/apple/src"),
				`apple@{rev}`
			)
		)

		local result = run("--vendor")

		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(vendored("apple@feature%2Fx", "init.luau")), "return 'apple'\n")
		assert.that(not fs.exists(vendored("apple@feature%2Fx", "tests")))
		assert.that(not fs.exists(vendored("apple@feature%2Fx", "pkg.luau")))
		assert.that(not fs.exists(vendored("apple@feature")))
	end)
end)
