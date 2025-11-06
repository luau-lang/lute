local finder = require("@self/finder")
local luau = require("@std/luau")
local path = require("@std/path")
local test = require("@std/test")

local function printHelp()
	print([[
Usage: lute test [OPTIONS] [PATHS...]

Run tests discovered in .test.luau and .spec.luau files.

OPTIONS:
  -h, --help              Show this help message
  --list                  List all discovered test cases without running them
  --filter=PATTERN        Run only tests matching PATTERN
                          Examples:
                            --filter=SuiteName           (run all tests in suite)
                            --filter=SuiteName.testname  (run specific test)
                            --filter=testname            (run anonymous test)
  --reporter=REPORTER     Choose test reporter (default: rich)
                          Options:
                            rich    - Color output with visual diffs
                            simple  - Plain text output
                            <path>  - Custom reporter from file path

PATHS:
  Directories or files to search for tests (default: ./tests)

EXAMPLES:
  lute test                                    Run all tests in ./tests
  lute test --list                             List all test cases
  lute test --filter=MyTestSuite               Run all tests in MyTestSuite
  lute test --reporter=simple src/             Run tests with simple reporter
]])
end

--[[
 Any of the tests we load will use the instance of std/test initialized in this module (cli/commands/test/init.luau)
 Tests that run via lute test don't need to explicitly call test.run, so we'll pass an empty run function so that we don't
 execute any tests, while giving us time to remove unecessary run() calls (doing this because this doesn't support running tests just yet)
 The reason we have to inject a custom require here is because each `loadbypath` on a test file will return the "@std/test" instance provided by
 the EmbeddedStdVFS. However, running `lute test` from the root of the lute repo will use a distinct @std/test instance, which is provided by the .luaurc when running
 this file, which means the test environment won't get populated. The consequence of this is that `lute test` will work perfectly everywhere except inside of
 the lute repo, which sucks. Intercepting @std/test requires works correctly and ensures that the correct @std/test instance gets populated
]]
--
local function lutetestrequire(req: string)
	if req == "@std/test" then
		return table.freeze({ case = test.case, suite = test.suite, run = function() end })
	end
	return require(req) :: any
end

local function loadtests(testfiles: { path.path })
	local fenv: { [unknown]: unknown } = setmetatable({ ["require"] = lutetestrequire }, { __index = _G })
	-- Load all test files first
	for _, p in testfiles do
		local success, err = pcall(luau.loadbypath, p, fenv)

		if not success then
			print(`Error loading {path.format(p)}: {err}`)
		end
	end
end

local function listtests()
	-- Gets all registered tests using the shared test instance
	local registered = test._registered()
	local totalTests = #registered.anonymous

	for _, suite in registered.suites do
		totalTests += #suite.cases
	end

	print("Anonymous:")
	for _, tc in registered.anonymous do
		print(`\t{tc.name}`)
	end

	for _, suite in registered.suites do
		print(`{suite.name}:`)
		for _, tc in suite.cases do
			print(`\t{tc.name}`)
		end
	end
end

local function main(...: string)
	local args = { ... }
	local testPaths = {}
	local isListMode = false

	for _, arg in args do
		if arg == "-h" or arg == "--help" then
			printHelp()
			return
		elseif arg == "--list" then
			isListMode = true
		else
			table.insert(testPaths, arg)
		end
	end
	local searchpath = if #testPaths > 0 then testPaths else { "./tests" }
	loadtests(finder.findtestfiles(searchpath))

	if isListMode then
		listtests()
	end
end

main(...)
