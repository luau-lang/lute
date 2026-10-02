local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")
local server = require("@lute/net/server")
local system = require("@std/system")

local registry = require("@commands/pkg/loom-core/src/registry")

local lutePath = path.format(process.execPath())
local testFilePath = debug.info(1, "s"):gsub("^@", "")
local fetchRegistryFixture = path.join(path.dirname(testFilePath), "fixtures", "fetch_registry.luau")
local credentialWorkingDirectory = path.join(system.tmpdir(), "lute-pkg-registry-credentials")

test.suite("RegistryClient", function(suite)
	suite:case("authFailureSuggestsAuthCommand", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(): server.ServerResponse
				return { status = 401, body = "unauthorized" }
			end,
		})

		local ok, err = pcall(function()
			registry.fetchUniverse(`http://{instance.hostname}:{instance.port}`, {
				{ name = "citrus", source = "citrus" },
			})
		end)
		assert.that(not ok)
		assert.strContains(tostring(err), "Run `lute pkg auth --domain")

		instance.close()
	end)

	suite:case("passesHttpRegistryProtocolToCredentialProvider", function(assert)
		if fs.exists(credentialWorkingDirectory) then
			fs.removeDirectory(credentialWorkingDirectory, { recursive = true })
		end
		fs.createDirectory(credentialWorkingDirectory)

		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				assert.eq(req.path, "/api/v1/package-index/citrus")
				return {
					status = 200,
					body = '[{"name":"citrus","version":"1.0.0","yanked":false,"dependencies":[]}]',
				}
			end,
		})
		local registryUrlValue = `http://{instance.hostname}:{instance.port}`
		local registryHost = `{instance.hostname}:{instance.port}`

		fs.writeStringToFile(
			path.join(credentialWorkingDirectory, ".config.luau"),
			[[return {
		lute = {
			credentials = {
				providers = { "./credentials.luau" },
			},
		},
	}
]]
		)
		fs.writeStringToFile(
			path.join(credentialWorkingDirectory, "credentials.luau"),
			'return {\n\thost = "'
				.. registryHost
				.. '",\n\tresolve = function(request)\n\t\tassert(request.protocol == "http")\n\t\treturn "registry-test-token"\n\tend,\n}\n'
		)

		local result = process.run({ lutePath, path.format(fetchRegistryFixture), registryUrlValue }, {
			cwd = path.format(credentialWorkingDirectory),
			env = setmetatable({ LOOM_REGISTRY_TOKEN = "" }, { __index = process.env }),
		})
		assert.eq(result.exitcode, 0)

		instance.close()
		fs.removeDirectory(credentialWorkingDirectory, { recursive = true })
	end)

	suite:case("indexToPackageVersions_basicEntry", function(assert)
		local entries = {
			{
				name = "citrus",
				version = "1.0.0",
				yanked = false,
				dependencies = {},
			},
			{
				name = "citrus",
				version = "1.1.0",
				yanked = false,
				dependencies = {},
			},
		}

		local versions = registry.indexToPackageVersions(entries, "citrus")
		assert.eq(#versions, 2)
		assert.eq(versions[1].name, "citrus")
		assert.eq(versions[1].versionString, "1.0.0")
		assert.eq(versions[2].versionString, "1.1.0")
	end)

	suite:case("indexToPackageVersions_filtersYanked", function(assert)
		local entries = {
			{
				name = "citrus",
				version = "1.0.0",
				yanked = false,
				dependencies = {},
			},
			{
				name = "citrus",
				version = "1.1.0",
				yanked = true,
				dependencies = {},
			},
			{
				name = "citrus",
				version = "1.2.0",
				yanked = false,
				dependencies = {},
			},
		}

		local versions = registry.indexToPackageVersions(entries, "citrus")
		assert.eq(#versions, 2)
		assert.eq(versions[1].versionString, "1.0.0")
		assert.eq(versions[2].versionString, "1.2.0")
	end)

	suite:case("indexToPackageVersions_parsesDependencies", function(assert)
		local entries = {
			{
				name = "citrus",
				version = "1.0.0",
				yanked = false,
				dependencies = {
					{
						name = "lemon",
						versionRequirement = "^2.0.0",
					},
					{
						name = "lime",
						alias = "myLime",
						versionRequirement = ">=1.0.0 <2.0.0",
					},
				},
			},
		}

		local versions = registry.indexToPackageVersions(entries, "citrus")
		assert.eq(#versions, 1)

		local deps = versions[1].dependencies
		assert.neq(deps.lemon, nil)
		assert.eq(deps.lemon.name, "lemon")

		assert.neq(deps.myLime, nil)
		assert.eq(deps.myLime.name, "lime")
	end)

	suite:case("indexToPackageVersions_skipsInvalidVersions", function(assert)
		local entries = {
			{
				name = "citrus",
				version = "not-a-version",
				yanked = false,
				dependencies = {},
			},
			{
				name = "citrus",
				version = "1.0.0",
				yanked = false,
				dependencies = {},
			},
		}

		local versions = registry.indexToPackageVersions(entries, "citrus")
		assert.eq(#versions, 1)
		assert.eq(versions[1].versionString, "1.0.0")
	end)

	suite:case("indexToPackageVersions_dependencyWithoutAlias", function(assert)
		local entries = {
			{
				name = "citrus",
				version = "1.0.0",
				yanked = false,
				dependencies = {
					{
						name = "lemon",
						versionRequirement = "^1.0.0",
					},
				},
			},
		}

		local versions = registry.indexToPackageVersions(entries, "citrus")
		local deps = versions[1].dependencies
		assert.neq(deps.lemon, nil)
		assert.eq(deps.lemon.name, "lemon")
	end)

	suite:case("indexToPackageVersions_emptyAlias", function(assert)
		local entries = {
			{
				name = "citrus",
				version = "1.0.0",
				yanked = false,
				dependencies = {
					{
						name = "lemon",
						alias = "",
						versionRequirement = "^1.0.0",
					},
				},
			},
		}

		local versions = registry.indexToPackageVersions(entries, "citrus")
		local deps = versions[1].dependencies
		assert.neq(deps.lemon, nil)
		assert.eq(deps.lemon.name, "lemon")
	end)

	suite:case("fetchUniverse_usesSourceAsThePackageName", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				assert.eq(req.path, "/api/v1/package-index/org/citrus")
				return {
					status = 200,
					body = [[
[{"name":"org/citrus","version":"1.0.0","yanked":false,"dependencies":[]}]
]],
				}
			end,
		})

		local universe = registry.fetchUniverse(`http://{instance.hostname}:{instance.port}`, {
			{
				name = "org/citrus",
				source = "org/citrus",
			},
		})

		assert.neq(universe["org/citrus"], nil)
		assert.eq(universe["org/citrus"][1].name, "org/citrus")
		assert.eq(universe["org/citrus"][1].versionString, "1.0.0")

		instance.close()
	end)
end)
