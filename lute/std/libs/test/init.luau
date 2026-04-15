--!strict
-- @std/test
-- Standard test library for Luau

local types = require("@self/types")
local env = require("@self/env")

type Test = types.Test
type TestCase = types.TestCase
type TestSuite = types.TestSuite
type TestReporter = types.TestReporter

local TestSuite = {}
TestSuite.__index = TestSuite

--- Creates a new, empty `TestSuite` with the given `name`.
function TestSuite.new(name: string): TestSuite
	local self = setmetatable({
		name = name,
		cases = {},
		_beforeEach = nil,
		_beforeAll = nil,
		_afterEach = nil,
		_afterAll = nil,
	}, TestSuite)
	return self :: TestSuite
end

--- Registers a test case with `name` in this suite.
function TestSuite:case(name: string, testCase: Test)
	table.insert(self.cases, { name = name, case = testCase })
end

--- Registers a hook to run before each test case in this suite.
function TestSuite:beforeEach(hook: () -> ())
	self._beforeEach = hook
end

--- Registers a hook to run once before all test cases in this suite.
function TestSuite:beforeAll(hook: () -> ())
	self._beforeAll = hook
end

--- Registers a hook to run after each test case in this suite.
function TestSuite:afterEach(hook: () -> ())
	self._afterEach = hook
end

--- Registers a hook to run once after all test cases in this suite.
function TestSuite:afterAll(hook: () -> ())
	self._afterAll = hook
end

-- Test library export surface
local test = {}

--- Registers an anonymous (top-level) test case with the given `name`.
function test.case(name: string, case: Test)
	local testcase = { name = name, case = case }
	table.insert(env.anonymous, testcase)

	-- Update caseindex
	if not env.caseindex[name] then
		env.caseindex[name] = { anonymous = { testcase }, suites = {} }
	else
		table.insert(env.caseindex[name].anonymous, testcase)
	end
end

--- Registers a test suite with `name`, using `registerFn` to define its test cases.
function test.suite(name: string, registerFn: (TestSuite) -> ())
	local suite = TestSuite.new(name)
	registerFn(suite)
	table.insert(env.suites, suite)

	-- Update suiteindex
	env.suiteindex[name] = suite

	-- Update caseindex for all cases in this suite
	for _, testcase in suite.cases do
		if not env.caseindex[testcase.name] then
			env.caseindex[testcase.name] = { anonymous = {}, suites = {} }
		end
		if not env.caseindex[testcase.name].suites[name] then
			env.caseindex[testcase.name].suites[name] = {}
		end
		table.insert(env.caseindex[testcase.name].suites[name], testcase)
	end
end

-- get all registered tests without running them (internal)
function test._registered()
	return table.freeze({
		anonymous = env.anonymous,
		suites = env.suites,
		suiteindex = env.suiteindex,
		caseindex = env.caseindex,
	})
end

return table.freeze(test)
