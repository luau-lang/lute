local luau = require("@std/luau")
local env = require("@std/test/env")
local runner = require("@std/test/runner")
local types = require("@std/test/types")
local filter = require("./filter")

local function reset()
	table.clear(env.anonymous)
	table.clear(env.suites)
	table.clear(env.suiteindex)
	table.clear(env.caseindex)
end

local function loadFailure(filepath: string, err: any): types.FailedTest
	return {
		test = filepath,
		failure = {
			msg = `failed to load test file: {tostring(err)}`,
			stacktrace = "",
			__tag = "runtime_error",
		},
	}
end

local function runfile(
	args: { file: string, suite: string?, case: string?, verbose: boolean? }
): types.TestRunResult
	reset()

	local ok, err = pcall(luau.loadModule, args.file, nil)
	if not ok then
		return {
			failures = { loadFailure(args.file, err) },
			total = 1,
			passed = 0,
			failed = 1,
		}
	end

	local filtered = filter.filtertests(env, args.suite, args.case)
	return runner.run(filtered, { verbose = args.verbose == true })
end

return table.freeze({ runfile = runfile })
