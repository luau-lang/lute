--!strict
-- @std/test
-- Standard test library for Luau

local types = require("@self/types")

local reporter = require("@self/reporter")
local runner = require("@self/runner")
local ps = require("@std/process")

type Test = types.test
type TestCase = types.testcase
export type TestSuite = types.testsuite
type TestEnvironment = types.testenvironment
type TestReporter = types.testreporter

local TestSuite = {}
TestSuite.__index = TestSuite

function TestSuite.new(name: string): TestSuite
	local self = setmetatable({
		name = name,
		cases = {},
		_beforeeach = nil,
		_beforeall = nil,
		_aftereach = nil,
		_afterall = nil,
	}, TestSuite)
	return self :: TestSuite
end

function TestSuite:case(name: string, testCase: Test)
	table.insert(self.cases, { name = name, case = testCase })
end

function TestSuite:beforeeach(hook: () -> ())
	self._beforeeach = hook
end

function TestSuite:beforeall(hook: () -> ())
	self._beforeall = hook
end

function TestSuite:aftereach(hook: () -> ())
	self._aftereach = hook
end

function TestSuite:afterall(hook: () -> ())
	self._afterall = hook
end

local env: TestEnvironment = { anonymous = {}, suites = {}, reporter = reporter.simple }

-- Test library export surface
local test = {}

function test.setreporter(reporter: TestReporter)
	test.reporter = reporter
end

-- register an anonymous test case
function test.case(name: string, case: Test)
	local testcase = { name = name, case = case }
	table.insert(env.anonymous, testcase)
end

-- register a test suite
function test.suite(name: string, registerFn: (TestSuite) -> ())
	local suite = TestSuite.new(name)
	registerFn(suite)
	table.insert(env.suites, suite)
end

-- get all registered tests without running them (internal)
function test._registered()
	return table.freeze({ anonymous = env.anonymous, suites = env.suites })
end

-- run all the tests
function test.run()
	local failed = runner.run(env)
	reporter.simple(failed)
	if failed.failed ~= 0 then
		ps.exit(1)
	end
	ps.exit(0)
end

return table.freeze(test)
