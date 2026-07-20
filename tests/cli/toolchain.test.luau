local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())
local testRoot = path.join(system.tmpdir(), `lute-toolchain-test-{process.pid()}`)
local hostVersion = string.match(process.run({ lutePath, "--version" }).stdout, "(%d+%.%d+%.%d+[%w%.%-]*)") or ""

local function cleanup()
	if fs.exists(testRoot) then
		fs.removeDirectory(testRoot, { recursive = true })
	end
end

local function makeEnv(overrides: { [string]: string }?): { [string]: string }
	local env = setmetatable({}, { __index = process.env }) :: any
	env.HOME = path.format(testRoot)
	env.USERPROFILE = path.format(testRoot)
	if overrides then
		for k, v in overrides do
			env[k] = v
		end
	end
	return env
end

local function writeConfig(dir: path.Path, version: string)
	local configPath = path.format(path.join(dir, ".config.luau"))
	fs.writeStringToFile(
		configPath,
		`return \{\n\tlute = \{\n\t\ttoolchain = \{\n\t\t\tlute = "{version}",\n\t\t\},\n\t\},\n\}`
	)
end

test.suite("LuteToolchainDispatch", function(suite)
	suite:beforeEach(function()
		cleanup()
		fs.createDirectory(testRoot, { makeParents = true })
	end)

	suite:afterAll(function()
		cleanup()
	end)

	suite:case("noConfigNoDispatch", function(assert)
		local result = process.run({ lutePath, "--version" }, { cwd = path.format(testRoot), env = makeEnv() })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, hostVersion)
	end)

	suite:case("skipDispatchEnvSkipsDispatch", function(assert)
		local projectDir = path.join(testRoot, "project")
		fs.createDirectory(projectDir, { makeParents = true })
		writeConfig(projectDir, "v99.99.99")

		local env = makeEnv({ LUTE_SKIP_DISPATCH = "1" })
		local result = process.run({ lutePath, "--version" }, { cwd = path.format(projectDir), env = env })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, hostVersion)
	end)

	suite:case("selfCommandNeverDispatches", function(assert)
		local projectDir = path.join(testRoot, "project")
		fs.createDirectory(projectDir, { makeParents = true })
		writeConfig(projectDir, "v99.99.99")

		local result = process.run({ lutePath, "self", "--help" }, { cwd = path.format(projectDir), env = makeEnv() })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Manage the host lute installation")
	end)

	suite:case("toolchainCommandNeverDispatches", function(assert)
		local projectDir = path.join(testRoot, "project")
		fs.createDirectory(projectDir, { makeParents = true })
		writeConfig(projectDir, "v99.99.99")

		local result = process.run({ lutePath, "toolchain" }, { cwd = path.format(projectDir), env = makeEnv() })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, ".config.luau")
	end)

	suite:case("dispatchesToCachedBinary", function(assert)
		local projectDir = path.join(testRoot, "project")
		fs.createDirectory(projectDir, { makeParents = true })

		-- Use the current lute version as the pin so it resolves to a real binary
		local versionResult = process.run({ lutePath, "--version" })
		local version = string.match(versionResult.stdout, "(%d+%.%d+%.%d+[%w%.%-]*)")
		if version == nil then
			return -- skip if we can't parse version
		end

		local tag = `v{version}`
		writeConfig(projectDir, tag)

		-- Place the current binary in the expected cache location
		local exeName = if system.win32 then "lute.exe" else "lute"
		local cacheDir = path.join(testRoot, ".lute", "versions", "lute", tag)
		fs.createDirectory(cacheDir, { makeParents = true })

		local srcBytes = fs.readFileToString(lutePath)
		local cachedBinary = path.format(path.join(cacheDir, exeName))
		fs.writeStringToFile(cachedBinary, srcBytes)

		if not system.win32 then
			process.run({ "chmod", "+x", cachedBinary })
		end

		local env = makeEnv()
		local result = process.run({ lutePath, "--version" }, { cwd = path.format(projectDir), env = env })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, version)
	end)

	suite:case("invalidConfigShowsError", function(assert)
		local projectDir = path.join(testRoot, "project")
		fs.createDirectory(projectDir, { makeParents = true })

		-- Write config with non-string lute pin
		local configPath = path.format(path.join(projectDir, ".config.luau"))
		fs.writeStringToFile(configPath, "return { lute = { toolchain = { lute = 123 } } }")

		local result = process.run({ lutePath, "run", "--help" }, { cwd = path.format(projectDir), env = makeEnv() })

		assert.neq(result.exitcode, 0)
		assert.strContains(result.stderr .. result.stdout, "must be a string")
	end)
end)
