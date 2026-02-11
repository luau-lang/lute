local rt = require("@batteries/richterm")
local tys = require("@std/test/types")

local function splitStacktrace(stacktrace: string): { string }
	local lines = {}
	for line in stacktrace:gmatch("[^\n]+") do
		table.insert(lines, line)
	end
	return lines
end

-- Styles
local pass = rt.combine(rt.green, rt.bold)
local fail = rt.combine(rt.red, rt.bold)
local testname = rt.combine(rt.bold, rt.white)
local errlabel = rt.yellow
local errmsg = rt.red
local stkframe = rt.red
local location = rt.cyan
local dim = rt.dim
local separator = dim

local function printFailure(failed: tys.failedtest)
	print(fail("  FAIL ") .. testname(failed.test))
	if failed.failure.__tag == "assertion" then
		print(location(`\t{failed.failure.filename}:{failed.failure.linenumber}`))
		print(errmsg(`\t{failed.failure.assertion}: {failed.failure.msg}`))
	elseif failed.failure.__tag == "lifecycle" then
		print(location(`\t{failed.failure.filename}:{failed.failure.linenumber}`))
		print(errmsg(`\t{failed.failure.hook}: {failed.failure.msg}`))
	else
		print(errlabel("\tRuntime error: ") .. errmsg(failed.failure.msg))
		print(stkframe("\tStacktrace:"))
		for _, line in splitStacktrace(failed.failure.stacktrace) do
			print(stkframe(`\t  {line}`))
		end
	end
end

local function printSummary(result: tys.testrunresult)
	print(separator(string.rep("─", 50)))
	print(
		rt.bold("Results: ")
			.. pass(`{result.passed} passed`)
			.. dim(", ")
			.. fail(`{result.failed} failed`)
			.. dim(` of {result.total}`)
	)
end

local function colorReporter(result: tys.testrunresult)
	if #result.failures > 0 then
		print("")
		print(fail("Failures:"))
		print("")
		for _, failed in result.failures do
			printFailure(failed)
			print("")
		end
	end

	printSummary(result)
end

return { color = colorReporter }
