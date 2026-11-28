local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local testutil = require("../testutil")

local lutePath = path.format(process.execPath())

local expected = [[Anonymous:
	passing
ExampleSuite:
	shouldPass
SmokeSuite:
	makeFail
	makePass
]]

test.suite("LuteTestCommand", function(suite)
	suite:case("luteTestHelpMessage", function(assert)
		-- Run lute test with -h flag
		local result = process.run({ lutePath, "test", "-h" })

		-- Check that it exits successfully and prints both the usage line and the options
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Usage: lute test [options] [paths...]")
		assert.strContains(result.stdout, "Options:")
	end)

	suite:case("luteTestRunsTestsInDiscoveryFolder", function(assert)
		-- Run lute test on tests/cli/discovery folder
		local result = process.run({ lutePath, "test", "tests/cli/discovery" })

		-- Check that it runs tests and succeeds
		assert.eq(result.exitcode, 0)
	end)

	suite:case("luteTestDiscoveryCustomDirectory", function(assert)
		-- Run lute test with custom directory path
		local result = process.run({ lutePath, "test", "--list", "tests/cli/discovery" })

		-- Check that it discovers test files (.test.luau and .spec.luau)
		assert.eq(result.exitcode, 0)
		assert.eq(expected, testutil.normalizeLineEndings(result.stdout))
	end)

	suite:case("filterBySuiteName", function(assert)
		-- Run lute test with --suite flag
		local result = process.run({ lutePath, "test", "-s", "SmokeSuite", "tests/cli/discovery" })

		-- Check that it runs only tests in SmokeSuite
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("of 2", 1, true), nil)
		assert.neq(result.stdout:find("2 passed", 1, true), nil)
	end)

	suite:case("luteTestFiltersByCaseName", function(assert)
		-- Run lute test with --case flag
		local result = process.run({ lutePath, "test", "--case", "makePass", "tests/cli/discovery" })

		-- Check that it runs only tests named make_pass
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("of 1", 1, true), nil)
		assert.neq(result.stdout:find("1 passed", 1, true), nil)
	end)

	suite:case("luteTestFiltersBySuiteAndCaseName", function(assert)
		-- Run lute test with both --suite and --case flags
		local result = process.run({ lutePath, "test", "-s", "SmokeSuite", "-c", "makeFail", "tests/cli/discovery" })

		-- Check that it runs only make_fail in SmokeSuite
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("of 1", 1, true), nil)
		assert.neq(result.stdout:find("1 passed", 1, true), nil)
	end)

	suite:case("luteTestSnapshotsFiltersByCaseName", function(assert)
		local snapshotDir = "tests/cli/format/snapshots"
		local result = process.run({ lutePath, "test", "snapshots", "-c", "check_formatted_file", snapshotDir })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "check_formatted_file.snap.luau")
		assert.strContains(result.stdout, "1 passed")
		assert.strNotContains(result.stdout, "check_unformatted_file.snap.luau")

		local missing = process.run({ lutePath, "test", "snapshots", "--case", "does_not_exist", snapshotDir })
		assert.eq(missing.exitcode, 0)
		assert.strContains(missing.stdout, "No snapshot tests named 'does_not_exist' found.")
		assert.strNotContains(missing.stdout, ".snap.luau")
	end)

	suite:case("luteTestSnapshotsReplacesRootWithPatternCharacters", function(assert)
		-- Setup: a working directory whose name contains Lua pattern magic characters
		local rootDir = path.join(system.tmpdir(), "lute-snap root+(1)")
		if fs.exists(rootDir) then
			fs.removeDirectory(rootDir, { recursive = true })
		end
		fs.createDirectory(rootDir)
		fs.writeStringToFile(
			path.join(rootDir, "cwd.snap.luau"),
			'print(require("@std/path").format(require("@std/process").cwd()))\n'
		)
		fs.writeStringToFile(path.join(rootDir, "cwd.snap"), "<ROOT>\n")

		-- Run lute test snapshots from that directory
		local result = process.run({ lutePath, "test", "snapshots", "." }, { cwd = path.format(rootDir) })

		-- Check that the working directory in the output was replaced with <ROOT>
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("1 passed", 1, true), nil)

		-- Teardown
		fs.removeDirectory(rootDir, { recursive = true })
	end)
end)
