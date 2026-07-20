local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())
local testFilePath = debug.info(1, "s"):gsub("^@", "")
local fixturesDir = path.join(path.dirname(testFilePath), "fixtures")
local resolveFixture = path.join(fixturesDir, "resolve_credential.luau")

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-auth")
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

local function runResolve(
	fixture: string,
	domain: string,
	expectedToken: string
): { exitcode: number, stdout: string, stderr: string }
	return process.run({
		lutePath,
		path.format(resolveFixture),
		"https",
		domain,
		TEST_REPOSITORY,
		expectedToken,
	}, {
		cwd = path.format(path.join(fixturesDir, "credentials", fixture)),
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

	suite:case("resolvesTokenFromConfiguredProvider", function(assert)
		local result = runResolve("valid", TEST_DOMAIN, TEST_TOKEN)
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("returnsNilWithoutMatchingProvider", function(assert)
		local result = runResolve("no-match", TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("returnsNilWithoutConfig", function(assert)
		-- workingDirectory has no .config.luau
		local result = process.run({
			lutePath,
			path.format(resolveFixture),
			"https",
			TEST_DOMAIN,
			TEST_REPOSITORY,
			"<nil>",
		}, {
			cwd = path.format(workingDirectory),
			env = environment(),
		})
		assert.eq(result.exitcode, 0)
		assert.eq(result.stdout, "")
	end)

	suite:case("propagatesProviderErrors", function(assert)
		local result = runResolve("error", TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Credential provider for github.com failed")
		assert.strContains(result.stderr, "resolver failed")
	end)

	suite:case("rejectsTokenWithControlCharacters", function(assert)
		local result = runResolve("control-chars", TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "control characters")
	end)

	suite:case("skipsInvalidProviderModules", function(assert)
		local result = runResolve("invalid-module", TEST_DOMAIN, TEST_TOKEN)
		assert.eq(result.exitcode, 0)
	end)

	suite:case("failsOnMalformedConfig", function(assert)
		local result = runResolve("broken-config", TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Failed to load config")
	end)

	suite:case("failsWhenProvidersIsNotAnArray", function(assert)
		local result = runResolve("invalid-providers-type", TEST_DOMAIN, "<nil>")
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "must be an array of strings")
	end)
end)
