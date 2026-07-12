local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-auth")
local luteConfigDirectory = path.join(workingDirectory, ".lute")
local luteConfigPath = path.join(luteConfigDirectory, "config.luau")
local loomAuthPath = path.join(workingDirectory, ".loom", "auth.luau")
local resolverFixturePath = path.join(workingDirectory, "credential_resolver.luau")

local TEST_DOMAIN = "github.com"
local TEST_REPOSITORY = "luau-lang/lute"
local TEST_TOKEN = "lute-credential-resolver-test-token"

local function environment(): { [string]: string }
	local env = table.clone(process.env)
	env.HOME = path.format(workingDirectory)
	env.USERPROFILE = path.format(workingDirectory)
	env.GITHUB_TOKEN = ""
	return env
end

local function writeConfig(content: string)
	fs.createDirectory(luteConfigDirectory, { makeParents = true })
	fs.writeStringToFile(luteConfigPath, content)
end

local function runAuth(): { exitcode: number, stdout: string, stderr: string }
	return process.run({
		lutePath,
		"pkg",
		"auth",
		"--token",
		TEST_TOKEN,
		"--domain",
		TEST_DOMAIN,
	}, {
		cwd = path.format(workingDirectory),
		env = environment(),
	})
end

local function runResolver(domain: string, expectedToken: string): { exitcode: number, stdout: string, stderr: string }
	return process.run({
		lutePath,
		path.format(resolverFixturePath),
		"https",
		domain,
		TEST_REPOSITORY,
		expectedToken,
	}, {
		env = environment(),
	})
end

test.suite("LutePkgAuth", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
		fs.writeStringToFile(
			resolverFixturePath,
			[[local credentials = require("@commands/pkg/loom-core/src/credentials")

local protocol, host, repositoryPath, expectedToken = select(2, ...)
local token = credentials.resolve(table.freeze({
	protocol = protocol,
	host = host,
	path = repositoryPath,
}))

if expectedToken == "<nil>" then
	assert(token == nil, `Expected no token, got {token}`)
else
	assert(token == expectedToken, `Expected token {expectedToken}, got {token}`)
end
]]
		)
	end)

	suite:afterEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
	end)

	suite:case("savesPlaintextCredentialToAuthStore", function(assert)
		local result = runAuth()
		assert.eq(result.exitcode, 0)
		assert.that(fs.exists(loomAuthPath))
		assert.strContains(fs.readFileToString(loomAuthPath), TEST_TOKEN)
	end)

	suite:case("resolvesTokenFromUserConfig", function(assert)
		writeConfig(
			`return \{\n\tcredentialResolvers = \{\n\t\t["{TEST_DOMAIN}"] = function(request)\n\t\t\tassert(request.protocol == "https")\n\t\t\tassert(request.host == "{TEST_DOMAIN}")\n\t\t\tassert(request.path == "{TEST_REPOSITORY}")\n\t\t\treturn "{TEST_TOKEN}"\n\t\tend,\n\t\},\n\}\n`
		)

		local result = runResolver(TEST_DOMAIN, TEST_TOKEN)
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("resolvesTokenFromWildcardResolver", function(assert)
		writeConfig(
			`return \{\n\tcredentialResolvers = \{\n\t\t["*"] = function()\n\t\t\treturn "{TEST_TOKEN}"\n\t\tend,\n\t\},\n\}\n`
		)

		local result = runResolver("some-other-host.com", TEST_TOKEN)
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("returnsNilWithoutMatchingResolver", function(assert)
		local result = runResolver(TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("propagatesResolverErrors", function(assert)
		writeConfig([[return {
	credentialResolvers = {
		["github.com"] = function()
			error("resolver failed")
		end,
	},
}
]])

		local result = runResolver(TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Credential resolver for github.com failed")
		assert.strContains(result.stderr, "resolver failed")
	end)

	suite:case("rejectsTokenWithControlCharacters", function(assert)
		writeConfig([[return {
	credentialResolvers = {
		["github.com"] = function()
			return "token\ninjection"
		end,
	},
}
]])

		local result = runResolver(TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "control characters")
	end)
end)
