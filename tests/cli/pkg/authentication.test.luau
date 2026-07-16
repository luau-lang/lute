local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())
local testFilePath = debug.info(1, "s"):gsub("^@", "")
local providerFixture = path.join(path.dirname(testFilePath), "fixtures", "credential_provider.luau")

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-auth")
local luteConfigDirectory = path.join(workingDirectory, ".lute")
local luteConfigPath = path.join(luteConfigDirectory, "config.luau")
local loomAuthPath = path.join(workingDirectory, ".loom", "auth.luau")

local TEST_DOMAIN = "github.com"
local TEST_REPOSITORY = "luau-lang/lute"
local TEST_TOKEN = "lute-credential-provider-test-token"

local function environment(): { [string]: string }
	return setmetatable({
		HOME = path.format(workingDirectory),
		USERPROFILE = path.format(workingDirectory),
		GITHUB_TOKEN = "",
	}, { __index = process.env }) :: any
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

local function runProvider(domain: string, expectedToken: string): { exitcode: number, stdout: string, stderr: string }
	return process.run({
		lutePath,
		path.format(providerFixture),
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
			`return \{\n\tcredentials = \{\n\t\t["{TEST_DOMAIN}"] = function(request)\n\t\t\tassert(request.protocol == "https")\n\t\t\tassert(request.host == "{TEST_DOMAIN}")\n\t\t\tassert(request.path == "{TEST_REPOSITORY}")\n\t\t\treturn "{TEST_TOKEN}"\n\t\tend,\n\t\},\n\}\n`
		)

		local result = runProvider(TEST_DOMAIN, TEST_TOKEN)
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("returnsNilWithoutMatchingProvider", function(assert)
		local result = runProvider(TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("propagatesProviderErrors", function(assert)
		writeConfig([[return {
	credentials = {
		["github.com"] = function()
			error("resolver failed")
		end,
	},
}
]])

		local result = runProvider(TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Credential provider for github.com failed")
		assert.strContains(result.stderr, "resolver failed")
	end)

	suite:case("rejectsTokenWithControlCharacters", function(assert)
		writeConfig([[return {
	credentials = {
		["github.com"] = function()
			return "token\ninjection"
		end,
	},
}
]])

		local result = runProvider(TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "control characters")
	end)
end)
