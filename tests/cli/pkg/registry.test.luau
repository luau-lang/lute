local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")
local server = require("@lute/net/server")
local system = require("@std/system")

local registry = require("@commands/pkg/loom-core/src/registry")
local store = require("@commands/pkg/loom-core/src/store")

local lutePath = path.format(process.execPath())
local testFilePath = debug.info(1, "s"):gsub("^@", "")
local fetchRegistryFixture = path.join(path.dirname(testFilePath), "fixtures", "fetch_registry.luau")
local publishRegistryFixture = path.join(path.dirname(testFilePath), "fixtures", "publish_registry.luau")
local credentialWorkingDirectory = path.join(system.tmpdir(), "lute-pkg-registry-credentials")
local publishWorkingDirectory = path.join(system.tmpdir(), "lute-pkg-registry-publish")

local function preparePublishCredentialProvider(domain: string, token: string)
	if fs.exists(publishWorkingDirectory) then
		fs.removeDirectory(publishWorkingDirectory, { recursive = true })
	end
	fs.createDirectory(publishWorkingDirectory)
	fs.writeStringToFile(
		path.join(publishWorkingDirectory, ".config.luau"),
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
		path.join(publishWorkingDirectory, "credentials.luau"),
		'return {\n\thost = "' .. domain .. '",\n\tresolve = function()\n\t\treturn "' .. token .. '"\n\tend,\n}\n'
	)
end

local function runPublish(
	registryUrl: string,
	artifactoryToken: string?
): { exitcode: number, stdout: string, stderr: string }
	return process.run({ lutePath, path.format(publishRegistryFixture), registryUrl }, {
		cwd = path.format(publishWorkingDirectory),
		env = setmetatable({
			HOME = path.format(publishWorkingDirectory),
			LOOM_ARTIFACTORY_TOKEN = artifactoryToken or "",
			USERPROFILE = path.format(publishWorkingDirectory),
		}, { __index = process.env }),
	})
end

test.suite("RegistryClient", function(suite)
	suite:case("usesUniqueStagingDirectoriesForIdenticalConcurrentInstalls", function(assert)
		local registryUrlValue = "https://registry.example.com"
		local first = registry.getTemporaryInstallDirectory(registryUrlValue, "org/citrus", "1.0.0")
		local second = registry.getTemporaryInstallDirectory(registryUrlValue, "org/citrus", "1.0.0")

		assert.neq(first, second)
		assert.strContains(first, store.getRegistryIdentity(registryUrlValue))
		assert.strContains(second, store.getRegistryIdentity(registryUrlValue))
	end)

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

	suite:case("publishRequiresARegistry", function(assert)
		assert.throwsWith(
			"No registry configured for publishing. Add a 'registry' field to loom.config.luau.",
			function()
				registry.publishPackage(nil, buffer.create(0))
			end
		)
	end)

	suite:case("publishRequiresAnArtifactoryToken", function(assert)
		if fs.exists(publishWorkingDirectory) then
			fs.removeDirectory(publishWorkingDirectory, { recursive = true })
		end
		fs.createDirectory(publishWorkingDirectory)

		local result = runPublish("https://registry.example.com", nil)
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "No Artifactory token configured for registry registry.example.com")
		assert.strContains(result.stderr, "lute pkg auth --domain registry.example.com")
	end)

	suite:case("publishSendsRawZipWithTheResolvedArtifactoryToken", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				assert.eq(req.method, "POST")
				assert.eq(req.path, "/api/v1/publish")
				assert.eq(req.headers["artifactory-token"], "publish-test-token")
				assert.eq(req.headers["content-type"], "application/zip")
				assert.eq(req.body, "package archive\0body")
				return { status = 200, body = "{}" }
			end,
		})
		local registryUrlValue = `http://{instance.hostname}:{instance.port}`
		preparePublishCredentialProvider(`{instance.hostname}:{instance.port}`, "publish-test-token")

		local result = runPublish(registryUrlValue, nil)
		assert.eq(result.exitcode, 0)

		instance.close()
		fs.removeDirectory(publishWorkingDirectory, { recursive = true })
	end)

	suite:case("publishUsesTheArtifactoryEnvironmentToken", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				assert.eq(req.headers["artifactory-token"], "environment-artifactory-token")
				return { status = 200, body = "{}" }
			end,
		})
		local registryUrlValue = `http://{instance.hostname}:{instance.port}`
		if fs.exists(publishWorkingDirectory) then
			fs.removeDirectory(publishWorkingDirectory, { recursive = true })
		end
		fs.createDirectory(publishWorkingDirectory)

		local result = runPublish(registryUrlValue, "environment-artifactory-token")
		assert.eq(result.exitcode, 0)

		instance.close()
		fs.removeDirectory(publishWorkingDirectory, { recursive = true })
	end)

	suite:case("publishReportsAuthenticationAndDuplicateVersionFailures", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				if req.headers["artifactory-token"] == "unauthorized-token" then
					return { status = 401, body = "unauthorized" }
				end
				return { status = 409, body = "already exists" }
			end,
		})
		local registryUrlValue = `http://{instance.hostname}:{instance.port}`
		preparePublishCredentialProvider(`{instance.hostname}:{instance.port}`, "unauthorized-token")

		local unauthorized = runPublish(registryUrlValue, nil)
		assert.eq(unauthorized.exitcode, 1)
		assert.strContains(unauthorized.stderr, "Registry publish authentication failed")

		preparePublishCredentialProvider(`{instance.hostname}:{instance.port}`, "duplicate-token")
		local duplicate = runPublish(registryUrlValue, nil)
		assert.eq(duplicate.exitcode, 1)
		assert.strContains(duplicate.stderr, "Package version already exists at registry")

		instance.close()
		fs.removeDirectory(publishWorkingDirectory, { recursive = true })
	end)

	suite:case("publishReportsUnexpectedResponses", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(): server.ServerResponse
				return { status = 500, body = "backend failure" }
			end,
		})
		local registryUrlValue = `http://{instance.hostname}:{instance.port}`
		preparePublishCredentialProvider(`{instance.hostname}:{instance.port}`, "publish-test-token")

		local result = runPublish(registryUrlValue, nil)
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Registry publish failed")
		assert.strContains(result.stderr, "backend failure")

		instance.close()
		fs.removeDirectory(publishWorkingDirectory, { recursive = true })
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
