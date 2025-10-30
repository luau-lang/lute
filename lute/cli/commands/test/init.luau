local finder = require("@self/finder")

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

local function main(...: string)
	local args = { ... }

	-- Check for help flag
	for _, arg in args do
		if arg == "-h" or arg == "--help" then
			printHelp()
			return
		end
	end

	local searchpath = if #args > 0 then args else { "./tests" }

	local files = finder.findtestfiles(searchpath)

	print(`Found {#files} test files`)
end

main(...)
