local rt = require("@batteries/richterm")
local path = require("@std/path")
local tys = require("@std/test/types")
local snapty = require("./snap/types")
local snapsty = require("./snap/styles")

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

local function printFailure(failed: tys.FailedTest)
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

local function printSummary(result: tys.TestRunResult)
	print(separator(string.rep("─", 50)))
	print(
		rt.bold("Results: ")
			.. pass(`{result.passed} passed`)
			.. dim(", ")
			.. fail(`{result.failed} failed`)
			.. dim(` of {result.total}`)
	)
end

local function colorReporter(result: tys.TestRunResult)
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

local function workerFailuresReporter(failures: { string })
	if #failures == 0 then
		return
	end

	print("")
	print(fail("Worker failures:"))
	print("")
	for _, msg in failures do
		print(errlabel("  WORKER ") .. msg)
	end
end

local function snapReporter(result: snapty.snapresult)
	local total = #result.passed + #result.failed + #result.new

	for _, p in result.passed do
		print(snapsty.pass("\tPASS ") .. snapsty.filepath(path.format(p.filepath)))
	end

	for _, n in result.new do
		print(snapsty.newstyle("\tNEW ") .. snapsty.filepath(path.format(n.filepath)))
	end

	if #result.failed > 0 then
		print("")
		print(snapsty.fail("Failures:"))
		print("")
		for _, f in result.failed do
			print(snapsty.fail("\tFAIL ") .. snapsty.filepath(path.format(f.filepath)))
			print("")
			if f.stderr and f.stderr ~= "" then
				print(snapsty.dim(`Failed to execute test process with err {f.stderr}`))
				print("")
			end

			if f.exitCondition and f.exitCondition.expected ~= f.exitCondition.actual then
				print(
					snapsty.fail(
						`Exit code mismatch: expected {f.exitCondition.expected}, got {f.exitCondition.actual}`
					)
				)
				print("")
			else
				print(f.diff)
				print("")
			end
		end
	end

	print(separator(string.rep("─", 50)))
	local parts = {}
	table.insert(parts, snapsty.pass(`{#result.passed} passed`))
	if #result.new > 0 then
		table.insert(parts, snapsty.newstyle(`{#result.new} new`))
	end
	if #result.failed > 0 then
		table.insert(parts, snapsty.fail(`{#result.failed} failed`))
	end
	print(snapsty.bold("Snapshots: ") .. table.concat(parts, snapsty.dim(", ")) .. snapsty.dim(` of {total}`))
end

return table.freeze({ color = colorReporter, snap = snapReporter, workerFailures = workerFailuresReporter })
