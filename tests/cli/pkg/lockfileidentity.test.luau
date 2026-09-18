local fs = require("@std/fs")
local lockfile = require("@commands/pkg/loom-core/src/lockfile")
local path = require("@std/path")
local store = require("@commands/pkg/loom-core/src/store")
local system = require("@std/system")
local test = require("@std/test")

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-lockfile-identity")
local lockfilePath = path.join(workingDirectory, "loom.lock.luau")

local function writeLockfile(contents: string)
	fs.writeStringToFile(lockfilePath, contents)
end

test.suite("RegistryLockfileIdentity", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("normalizesRegistryIdentityAndQualifiesStoreKeys", function(assert)
		local registryUrl = "https://registry.example.com"
		local registryUrlWithSlash = "https://registry.example.com/"
		local identity = store.getRegistryIdentity(registryUrl)
		local qualified = store.qualifyRegistryKey("citrus@1.0.0", registryUrl)

		assert.eq(identity, store.getRegistryIdentity(registryUrlWithSlash))
		assert.neq(identity, store.getRegistryIdentity("https://other-registry.example.com"))
		assert.eq(qualified, `citrus@1.0.0--registry-{identity}`)
		assert.eq(store.qualifyRegistryKey(qualified, registryUrl), qualified)
	end)

	suite:case("parsesOptionalRegistryFieldsInVersionThreeLockfiles", function(assert)
		writeLockfile([[return {
	version = 3,
	registry = "https://root-registry.example.com",
	dependencies = {
		citrus = "citrus@1.0.0",
	},
	packages = {
		["citrus@1.0.0"] = {
			name = "citrus",
			rev = "1.0.0",
			source = "citrus",
			sourceKind = "registry",
			registry = "https://package-registry.example.com",
			installPath = "@pkg/citrus@1.0.0",
			dependencies = {},
		},
	},
}
]])

		local lock = lockfile.parseFile(path.format(lockfilePath))
		assert.eq(lock.registry, "https://root-registry.example.com")
		assert.eq(lock.packages["citrus@1.0.0"].registry, "https://package-registry.example.com")
	end)

	suite:case("continuesToParseVersionThreeLockfilesWithoutRegistryFields", function(assert)
		writeLockfile([[return {
	version = 3,
	dependencies = {
		citrus = "citrus@1.0.0",
	},
	packages = {
		["citrus@1.0.0"] = {
			name = "citrus",
			rev = "1.0.0",
			source = "citrus",
			sourceKind = "registry",
			installPath = "@pkg/citrus@1.0.0",
			dependencies = {},
		},
	},
}
]])

		local lock = lockfile.parseFile(path.format(lockfilePath))
		assert.eq(lock.registry, nil)
		assert.eq(lock.packages["citrus@1.0.0"].registry, nil)
	end)

	suite:case("rejectsNonStringRegistryFields", function(assert)
		writeLockfile([[return {
	version = 3,
	registry = false,
	dependencies = {},
	packages = {},
}
]])

		assert.throwsWith("Expected 'registry' field to be a string or nil", function()
			lockfile.parseFile(path.format(lockfilePath))
		end)

		writeLockfile([[return {
	version = 3,
	dependencies = {
		citrus = "citrus@1.0.0",
	},
	packages = {
		["citrus@1.0.0"] = {
			name = "citrus",
			rev = "1.0.0",
			source = "citrus",
			sourceKind = "registry",
			registry = false,
			installPath = "@pkg/citrus@1.0.0",
			dependencies = {},
		},
	},
}
]])

		assert.throwsWith("Expected 'registry' field to be a string or nil for dependency 'citrus@1.0.0'", function()
			lockfile.parseFile(path.format(lockfilePath))
		end)
	end)
end)
