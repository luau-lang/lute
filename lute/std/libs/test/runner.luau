--!strict
-- @std/test/runner
-- Standard test runner library for Luau
local ps = require("@std/process")
local task = require("@std/task")
local time = require("@std/time")

local asserts = require("./assert")
local failure = require("./failure")
local reporter = require("./reporter")
local types = require("./types")
local env = require("./env")

type Test = types.Test
type TestCase = types.TestCase
type TestSuite = types.TestSuite
type TestEnvironment = types.TestEnvironment
type TestReporter = types.TestReporter
type FailedTest = types.FailedTest
type TestRunResult = types.TestRunResult
type TestTiming = types.TestTiming

local runner = {}

--- Options controlling how `runner.run` schedules work.
---
--- `parallelSuites` runs whole suites concurrently as coroutines, with at most
--- `parallelSuites` suites in flight at once. `nil` or `<= 1` keeps the existing
--- sequential behavior. Suite-level concurrency composes with `suite:parallel()`:
--- a suite that opted into parallel cases runs its cases concurrently within the
--- coroutine slot it occupies in the suite-parallel pool.
---
--- Tests in suites that run concurrently must not share mutable state (tmp file
--- paths, cwd, env vars, global tables). The lute lint suite is a worked example:
--- each case calls `freshScratchDir()` for its filesystem state.
export type RunOptions = {
	parallelSuites: number?,
}

--- Runs all test cases and suites in `env`, executing lifecycle hooks around each case. Returns the aggregate results.
function runner.run(env: TestEnvironment, options: RunOptions?): TestRunResult
	local maxSuiteConcurrency = if options and options.parallelSuites and options.parallelSuites > 1
		then options.parallelSuites
		else 1

	local failures: { FailedTest } = {}
	local timings: { TestTiming } = {}
	local total = 0
	local failed = 0
	local passed = 0

	local runstart = time.now()

	local function record(name: string, kind: "case" | "beforeAll" | "beforeEach" | "afterEach" | "afterAll", start)
		table.insert(timings, { name = name, kind = kind, seconds = time.since(start) })
	end

	-- Error handler for beforeAll hook
	local function beforeAllErrorHandler(suite: TestSuite)
		return function(err)
			-- If beforeAll fails, skip all tests in the suite
			total += #suite.cases
			failed += #suite.cases
			for _, tc in suite.cases do
				local failedtest: FailedTest = {
					test = `{suite.name}.{tc.name}`,
					failure = failure.lifecycle("beforeAll", err),
				}
				table.insert(failures, failedtest)
			end
			return err
		end
	end

	-- Error handler for beforeEach hook
	local function beforeEachErrorHandler(testFullName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = testFullName,
				failure = failure.lifecycle("beforeEach", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Error handler for afterEach hook
	local function afterEachErrorHandler(testFullName: string)
		return function(err)
			local failedtest: FailedTest = {
				test = testFullName,
				failure = failure.lifecycle("afterEach", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Error handler for afterAll hook
	local function afterAllErrorHandler(suiteName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = suiteName,
				failure = failure.lifecycle("afterAll", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Run anonymous tests
	for _, tc in env.anonymous do
		total += 1
		local function handlefailure(err)
			local wasruntimefailure = not (typeof(err) == "table" and err.__tag and err.__tag == "assertion")
			local failedtest: FailedTest = {
				test = tc.name,
				failure = if wasruntimefailure then failure.runtimeerror(err) else err,
			}
			table.insert(failures, failedtest)
			failed += 1
		end

		local casestart = time.now()
		local success = xpcall(tc.case, handlefailure, asserts)
		record(tc.name, "case", casestart)
		if success then
			passed += 1
		end
	end

	-- Runs a single case with its beforeEach/afterEach hooks and updates shared
	-- counters. The `beforeEach` error handler increments `failed` on its own if it
	-- fires, so this function leaves counters alone in that path and otherwise
	-- decides pass/fail based on the case + afterEach outcome.
	--
	-- Safe to call from multiple coroutines: Luau is cooperatively scheduled, so
	-- `+=` on the shared counters and `table.insert` into `failures` never race.
	local function runcase(suite: TestSuite, tc: TestCase)
		local testFullName = `{suite.name}.{tc.name}`
		local function handlefailure(err)
			local wasruntimefailure = not (typeof(err) == "table" and err.__tag and err.__tag == "assertion")
			local failedtest: FailedTest = {
				test = testFullName,
				failure = if wasruntimefailure then failure.runtimeerror(err) else err,
			}
			table.insert(failures, failedtest)
		end

		if suite._beforeEach then
			local hookstart = time.now()
			local beforeSuccess = xpcall(suite._beforeEach, beforeEachErrorHandler(testFullName))
			record(testFullName, "beforeEach", hookstart)
			if not beforeSuccess then
				-- beforeEachErrorHandler already bumped `failed`.
				return
			end
		end

		local casestart = time.now()
		local success = xpcall(tc.case, handlefailure, asserts)
		record(testFullName, "case", casestart)

		if suite._afterEach then
			local hookstart = time.now()
			local afterSuccess = xpcall(suite._afterEach, afterEachErrorHandler(testFullName))
			record(testFullName, "afterEach", hookstart)
			if not afterSuccess then
				success = false
			end
		end

		if success then
			passed += 1
		else
			failed += 1
		end
	end

	-- Runs a single suite end-to-end: beforeAll, all cases (sequential or parallel
	-- depending on `suite:parallel()`), then afterAll. Designed to be safe to call
	-- from a coroutine when running suites concurrently.
	local function runSuite(suite: TestSuite)
		if suite._beforeAll then
			local hookstart = time.now()
			local beforeAllSuccess = xpcall(suite._beforeAll, beforeAllErrorHandler(suite))
			record(suite.name, "beforeAll", hookstart)
			if not beforeAllSuccess then
				-- beforeAllErrorHandler already recorded total/failed for the skipped cases.
				return
			end
		end

		if suite._parallel then
			-- Parallel cases: launch each as a coroutine, capped at maxConcurrency
			-- in-flight. Yielding calls (process.run, net.*, fs.*) overlap via libuv.
			local maxConcurrency = suite._maxConcurrency or 8
			local numCases = #suite.cases
			total += numCases

			local pending = 0
			local completed = 0
			local launched = 0

			local function launchMore()
				while launched < numCases and pending < maxConcurrency do
					launched += 1
					local tc = suite.cases[launched]
					pending += 1
					task.spawn(function()
						runcase(suite, tc)
						pending -= 1
						completed += 1
					end)
				end
			end

			launchMore()
			while completed < numCases do
				task.wait()
				launchMore()
			end
		else
			for _, tc in suite.cases do
				total += 1
				runcase(suite, tc)
			end
		end

		if suite._afterAll then
			local hookstart = time.now()
			xpcall(suite._afterAll, afterAllErrorHandler(suite.name))
			record(suite.name, "afterAll", hookstart)
		end
	end

	if maxSuiteConcurrency <= 1 then
		for _, suite in env.suites do
			runSuite(suite)
		end
	else
		-- Suite-parallel mode: launch each suite as its own coroutine, with a cap on
		-- in-flight suites. A suite that opted into `:parallel()` will further fan
		-- out its cases inside its coroutine slot, giving two-level concurrency.
		local numSuites = #env.suites
		local pending = 0
		local completed = 0
		local launched = 0

		local function launchMore()
			while launched < numSuites and pending < maxSuiteConcurrency do
				launched += 1
				local suite = env.suites[launched]
				pending += 1
				task.spawn(function()
					runSuite(suite)
					pending -= 1
					completed += 1
				end)
			end
		end

		launchMore()
		while completed < numSuites do
			task.wait()
			launchMore()
		end
	end

	return {
		failures = failures,
		total = total,
		failed = failed,
		passed = passed,
		timings = timings,
		totalseconds = time.since(runstart),
	}
end

--- Runs all globally registered tests, prints the results with the simple reporter, then exits the process with code 0 on success or 1 on failure.
function runner.runRegisteredTests()
	local result = runner.run(env)
	reporter.simple(result)
	if result.failed ~= 0 then
		ps.exit(1)
	end
	ps.exit(0)
end

return table.freeze(runner)
