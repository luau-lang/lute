local fs = require("@std/fs")
local keyring = require("@lute/keyring")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())

-- Production code uses service "loom"; we share that service (so the CLI under test
-- writes to the real namespace) but use a domain unique to tests so we never collide
-- with a developer's real github.com entry.
local KEYRING_SERVICE = "loom"
local TEST_DOMAIN = "lute-keyring-test.example"
local TEST_TOKEN = "lute-keyring-test-token-not-a-real-credential"

local temporaryDirectory = system.tmpdir()
local workingDirectory = path.join(temporaryDirectory, "lute-pkg-auth")

local function runAuth(args: { string }): { exitcode: number, stdout: string, stderr: string }
	local cmd = { lutePath, "pkg", "auth" }
	for _, a in args do
		table.insert(cmd, a)
	end
	return process.run(cmd, { cwd = path.format(workingDirectory) })
end

local function clearTestEntry()
	if keyring.isSupported() then
		keyring.delete(KEYRING_SERVICE, TEST_DOMAIN)
	end
end

-- Probe the OS keyring once. macOS without an interactive session denies
-- writes via TCC (errAuthorizationDenied -60005); Linux has no backend at all.
-- In either case we skip the round-trip cases so the suite passes cleanly
-- everywhere except where round-trip behavior can actually be exercised.
local function keyringWritable(): boolean
	if not keyring.isSupported() then
		return false
	end
	local ok = pcall(keyring.set, "lute-keyring-canary", "probe", "probe")
	if ok then
		pcall(keyring.delete, "lute-keyring-canary", "probe")
	end
	return ok
end

test.suite("LutePkgAuth", function(suite)
	suite:beforeEach(function()
		clearTestEntry()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:afterEach(clearTestEntry)

	suite:case("printsHelpWithNoArgs", function(assert)
		local result = runAuth({})
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Usage: lute pkg auth")
		assert.strContains(result.stdout, "add")
		assert.strContains(result.stdout, "remove")
		assert.strContains(result.stdout, "migrate")
	end)

	suite:case("oldFlagOnlyInvocationErrors", function(assert)
		local result = runAuth({ "--token", "x" })
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Unknown action: --token")
	end)

	suite:case("unknownActionErrors", function(assert)
		local result = runAuth({ "bogus" })
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "Unknown action")
	end)

	suite:case("addStoresInKeyring", function(assert)
		if not keyringWritable() then
			return
		end

		local result = runAuth({ "add", "--token", TEST_TOKEN, "--domain", TEST_DOMAIN })
		assert.eq(result.exitcode, 0)
		assert.eq(keyring.get(KEYRING_SERVICE, TEST_DOMAIN), TEST_TOKEN)
	end)

	suite:case("addOverwritesExistingEntry", function(assert)
		if not keyringWritable() then
			return
		end

		keyring.set(KEYRING_SERVICE, TEST_DOMAIN, "stale-value")

		local result = runAuth({ "add", "--token", TEST_TOKEN, "--domain", TEST_DOMAIN })
		assert.eq(result.exitcode, 0)
		assert.eq(keyring.get(KEYRING_SERVICE, TEST_DOMAIN), TEST_TOKEN)
	end)

	suite:case("removeDeletesFromKeyring", function(assert)
		if not keyringWritable() then
			return
		end

		keyring.set(KEYRING_SERVICE, TEST_DOMAIN, TEST_TOKEN)

		local result = runAuth({ "remove", "--domain", TEST_DOMAIN })
		assert.eq(result.exitcode, 0)
		assert.eq(keyring.get(KEYRING_SERVICE, TEST_DOMAIN), nil)
	end)

	suite:case("migrateMovesLegacyFileIntoKeyring", function(assert)
		if not keyringWritable() then
			return
		end

		local homedir = path.format(process.homedir())
		local authPath = path.join(homedir, ".loom", "auth.luau")

		-- Leave any pre-existing auth.luau alone: snapshot it, run the test, restore.
		local hadOriginal = fs.exists(authPath)
		local original: string? = if hadOriginal then fs.readFileToString(authPath) else nil

		fs.createDirectory(path.join(homedir, ".loom"), { makeParents = true })
		fs.writeStringToFile(authPath, `return \{["{TEST_DOMAIN}"] = \{token = "{TEST_TOKEN}"}}\n`)

		local result = runAuth({ "migrate" })

		assert.eq(result.exitcode, 0)
		assert.eq(keyring.get(KEYRING_SERVICE, TEST_DOMAIN), TEST_TOKEN)
		assert.that(not fs.exists(authPath))

		if hadOriginal and original then
			fs.writeStringToFile(authPath, original)
		end
	end)
end)
