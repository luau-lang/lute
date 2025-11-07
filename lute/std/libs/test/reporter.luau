--!strict
-- @std/test/reporter
-- Standard test reporter library for Luau

local types = require("./types")
local assert = require("./assert")

type FailedTest = types.failedtest
type TestRunResult = types.testrunresult
type Assertions = assert.asserts

local reporter = {}

local function printFailedTest(failed: FailedTest)
	print(`❌ {failed.test}`)
	if failed.assertion ~= nil then
		print(`   {failed.filename}:{failed.linenumber}`)
		print(`   	{failed.assertion}: {failed.message}`)
	else
		print(`   Failed with: Runtime error in {failed.test} in:`)
		print(`   	{failed.filename}:{failed.linenumber}`)
	end
	print()
end

function reporter.simple(result: TestRunResult)
	print("\n" .. string.rep("=", 50))
	print("TEST RESULTS")
	print(string.rep("=", 50))

	if #result.failures > 0 then
		print(`\nFailed Tests ({#result.failures}):\n`)
		for _, failed in result.failures do
			printFailedTest(failed)
		end
	end

	print(string.rep("-", 50))
	print(`Total:  {result.total}`)
	print(`Passed: {result.passed} ✓`)
	print(`Failed: {result.failed} ✗`)
	print(string.rep("=", 50) .. "\n")
end

return table.freeze(reporter)
