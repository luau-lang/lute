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

local function formatSeconds(seconds: number): string
	if seconds >= 1 then
		return string.format("%.2fs", seconds)
	elseif seconds >= 0.001 then
		return string.format("%.1fms", seconds * 1000)
	else
		return string.format("%.0fµs", seconds * 1_000_000)
	end
end

local SLOW_LIMIT = 15
local SLOW_THRESHOLD_SECONDS = 0.01 -- only report entries >= 10ms

local function printTimings(result: tys.TestRunResult)
	local timings = result.timings
	if not timings or #timings == 0 then
		return
	end

	local suiteTotals: { [string]: number } = {}
	local suiteOrder: { string } = {}

	local sortable = table.clone(timings)
	table.sort(sortable, function(a, b)
		return a.seconds > b.seconds
	end)

	for _, t in timings do
		if t.kind == "case" then
			local suite = string.match(t.name, "^(.-)%.") or "(anonymous)"
			if suiteTotals[suite] == nil then
				suiteTotals[suite] = 0
				table.insert(suiteOrder, suite)
			end
			suiteTotals[suite] += t.seconds
		elseif t.kind == "beforeAll" or t.kind == "afterAll" then
			local suite = t.name
			if suiteTotals[suite] == nil then
				suiteTotals[suite] = 0
				table.insert(suiteOrder, suite)
			end
			suiteTotals[suite] += t.seconds
		elseif t.kind == "beforeEach" or t.kind == "afterEach" then
			local suite = string.match(t.name, "^(.-)%.") or "(anonymous)"
			if suiteTotals[suite] == nil then
				suiteTotals[suite] = 0
				table.insert(suiteOrder, suite)
			end
			suiteTotals[suite] += t.seconds
		end
	end

	table.sort(suiteOrder, function(a, b)
		return (suiteTotals[a] or 0) > (suiteTotals[b] or 0)
	end)

	print("")
	print(rt.bold("Slowest tests:"))
	local shown = 0
	for _, t in sortable do
		if t.seconds < SLOW_THRESHOLD_SECONDS then
			break
		end
		if shown >= SLOW_LIMIT then
			break
		end
		shown += 1
		local kindLabel = if t.kind == "case" then "" else ` [{t.kind}]`
		print(`  {location(formatSeconds(t.seconds))}  {testname(t.name)}{dim(kindLabel)}`)
	end
	if shown == 0 then
		print(dim(`  (no individual entries exceeded {formatSeconds(SLOW_THRESHOLD_SECONDS)})`))
	end

	print("")
	print(rt.bold("Slowest suites (sum of cases + hooks):"))
	local suiteShown = 0
	for _, suite in suiteOrder do
		if suiteShown >= SLOW_LIMIT then
			break
		end
		local secs = suiteTotals[suite] or 0
		if secs < SLOW_THRESHOLD_SECONDS then
			break
		end
		suiteShown += 1
		print(`  {location(formatSeconds(secs))}  {testname(suite)}`)
	end
	if suiteShown == 0 then
		print(dim(`  (no suites exceeded {formatSeconds(SLOW_THRESHOLD_SECONDS)})`))
	end
end

local function printSummary(result: tys.TestRunResult)
	print(separator(string.rep("─", 50)))
	local line = rt.bold("Results: ")
		.. pass(`{result.passed} passed`)
		.. dim(", ")
		.. fail(`{result.failed} failed`)
		.. dim(` of {result.total}`)
	if result.totalseconds then
		line ..= dim(` in {formatSeconds(result.totalseconds)}`)
	end
	print(line)
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

	printTimings(result)
	printSummary(result)
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

			print(f.diff)
			print("")
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

return table.freeze({ color = colorReporter, snap = snapReporter })
