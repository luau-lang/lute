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
end)

test.suite("LuteTestWorkerFailures", function(suite)
	local testDir = path.join(system.tmpdir(), `lute-test-worker-failures-{process.pid()}`)
	local testFile = path.join(testDir, "load.test.luau")

	suite:beforeEach(function()
		fs.createDirectory(testDir)
	end)

	suite:afterEach(function()
		fs.removeDirectory(testDir, { recursive = true })
	end)

	suite:case("reportsStacktraceForTestFileError", function(assert)
		fs.writeStringToFile(
			testFile,
			[[local function failLoad()
	error("test load failed", 0)
end
failLoad()
]]
		)

		local result = process.run({ lutePath, "test", path.format(testFile) })

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "Worker failures:")
		assert.strContains(result.stdout, "test load failed")
		assert.strContains(result.stdout, "load.test.luau:2 function failLoad")
		assert.strContains(result.stdout, "load.test.luau:4")
	end)

	suite:case("reportsStacktraceForRequiredModuleError", function(assert)
		fs.writeStringToFile(path.join(testDir, "dependency.luau"), 'error("dependency load failed", 0)')
		fs.writeStringToFile(
			testFile,
			[[local function loadDependency()
	return require("./dependency")
end
loadDependency()
]]
		)

		local result = process.run({ lutePath, "test", path.format(testFile) })

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "Worker failures:")
		assert.strContains(result.stdout, "dependency load failed")
		assert.strContains(result.stdout, "dependency.luau:1")
		assert.strContains(result.stdout, "load.test.luau:2 function loadDependency")
		assert.strContains(result.stdout, "load.test.luau:4")
	end)

	suite:case("successfulTestFileHasNoWorkerFailure", function(assert)
		fs.writeStringToFile(
			testFile,
			[[local test = require("@std/test")
test.case("passing", function(assert)
	assert.eq(1, 1)
end)
]]
		)

		local result = process.run({ lutePath, "test", path.format(testFile) })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "1 passed")
		assert.strNotContains(result.stdout, "Worker failures:")
	end)
end)
