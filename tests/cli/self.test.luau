local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local release = require("@commands/self/release")

local lutePath = path.format(process.execPath())

local function run(...: string): process.ProcessResult
	return process.run({ lutePath, "self", ... })
end

test.suite("LuteSelf", function(suite)
	suite:case("showsHelp", function(assert)
		local result = run("--help")

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Usage: lute self <command>")
		assert.strContains(result.stdout, "install")
		assert.strContains(result.stdout, "update")
		assert.strContains(result.stdout, "uninstall")
	end)

	suite:case("showsSubcommandHelp", function(assert)
		for _, command in { "install", "update", "uninstall" } do
			local result = run(command, "--help")

			assert.eq(result.exitcode, 0)
			assert.strContains(result.stdout, `Usage: lute self {command}`)
		end

		local updateHelp = run("update", "--help")
		assert.strContains(updateHelp.stdout, "--nightly")
		assert.strContains(updateHelp.stdout, "--version")
	end)

	suite:case("rejectsUnknownCommand", function(assert)
		local result = run("unknown")

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "Unknown command: unknown")
	end)

	suite:case("normalizesReleaseTags", function(assert)
		assert.throws(function()
			release.normalizeTag("")
		end, "Release version cannot be empty")

		assert.eq(release.normalizeTag("1.0.1"), "v1.0.1")
		assert.eq(release.normalizeTag("v1.0.1"), "v1.0.1")
		assert.eq(release.normalizeTag(" V1.0.1 "), "v1.0.1")
		assert.eq(release.normalizeTag("1.0.1-nightly.20260710"), "v1.0.1-nightly.20260710")
		assert.eq(release.normalizeTag("V1.0.1-NIGHTLY.20260710"), "v1.0.1-nightly.20260710")
	end)

	suite:case("classifiesNightlyTags", function(assert)
		assert.eq(release.isNightlyTag("v1.0.1"), false)
		assert.eq(release.isNightlyTag("1.0.1"), false)
		assert.eq(release.isNightlyTag("v1.0.1-nightly.20260710"), true)
		assert.eq(release.isNightlyTag("1.0.1-nightly.20260710"), true)
		assert.eq(release.isNightlyTag("V1.0.1-NIGHTLY.20260710"), true)
	end)

	suite:case("selectsLatestNightlyTag", function(assert)
		assert.eq(release.selectLatestNightlyTag({}), nil)
		assert.eq(
			release.selectLatestNightlyTag({
				{ tag_name = "v1.0.1", draft = false },
				{ tag_name = "v1.0.0", draft = false },
			}),
			nil
		)
		assert.eq(
			release.selectLatestNightlyTag({
				{ tag_name = "v1.0.1-nightly.20260715", draft = true },
				{ tag_name = "v1.0.1", draft = false },
				{ tag_name = "v1.0.1-nightly.20260714", draft = false },
				{ tag_name = "v1.0.1-nightly.20260710", draft = false },
			}),
			"v1.0.1-nightly.20260714"
		)
		assert.eq(
			release.selectLatestNightlyTag({
				{ tag_name = "v1.0.1-nightly.20260715", draft = false },
			}),
			"v1.0.1-nightly.20260715"
		)
	end)

	suite:case("installsAndUninstallsHostBinary", function(assert)
		local testHome = path.join(system.tmpdir(), `lute-self-{process.pid()}`)
		local env = setmetatable({}, { __index = process.env })
		env.HOME = path.format(testHome)
		env.USERPROFILE = path.format(testHome)
		env.SHELL = "/bin/zsh"

		local function runWithTestHome(...: string): process.ProcessResult
			return process.run({ lutePath, "self", ... }, { env = env })
		end

		if fs.exists(testHome) then
			fs.removeDirectory(testHome, { recursive = true })
		end
		fs.createDirectory(testHome, { makeParents = true })

		local installArguments = { "install", "--force" }
		local profile = path.join(testHome, ".zprofile")
		if system.win32 then
			table.insert(installArguments, "--no-modify-path")
		else
			fs.writeStringToFile(profile, "")
		end

		local installResult = runWithTestHome(table.unpack(installArguments))
		assert.eq(installResult.exitcode, 0)

		local executableName = if system.win32 then "lute.exe" else "lute"
		local installedBinary = path.join(testHome, ".lute", "bin", executableName)
		assert.that(fs.exists(installedBinary))

		local versionResult = process.run({ path.format(installedBinary), "--version" })
		assert.eq(versionResult.exitcode, 0)

		if not system.win32 then
			assert.strContains(fs.readFileToString(profile), "# >>> lute self install >>>")
		end

		local uninstallResult = runWithTestHome("uninstall", "--force", "--remove-data")
		assert.eq(uninstallResult.exitcode, 0)
		assert.eq(fs.exists(path.join(testHome, ".lute")), false)

		if not system.win32 then
			assert.strNotContains(fs.readFileToString(profile), "# >>> lute self install >>>")
		end

		fs.removeDirectory(testHome, { recursive = true })
	end)
end)
