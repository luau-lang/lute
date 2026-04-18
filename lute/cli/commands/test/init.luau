local cli = require("@batteries/cli")
local finder = require("@self/finder")
local filter = require("@self/filter")
local luau = require("@std/luau")
local path = require("@std/path")
local ps = require("@std/process")
local testtypes = require("@std/test/types")
local runner = require("@std/test/runner")
local reporter = require("@self/reporter")
local test = require("@std/test")
local time = require("@std/time")
local snaprunner = require("@self/snap/runner")
local updater = require("@self/snap/updater")

local SLOW_LOAD_LIMIT = 10
local SLOW_LOAD_THRESHOLD_SECONDS = 0.05

local function formatSeconds(seconds: number): string
	if seconds >= 1 then
		return string.format("%.2fs", seconds)
	elseif seconds >= 0.001 then
		return string.format("%.1fms", seconds * 1000)
	else
		return string.format("%.0fµs", seconds * 1_000_000)
	end
end

type LoadStats = {
	totalseconds: number,
	count: number,
	perfile: { { file: string, seconds: number } },
}

local function loadtests(testfiles: { path.Path }): LoadStats
	local loadstart = time.now()
	local perfile: { { file: string, seconds: number } } = {}
	-- Load all test files first
	for _, p in testfiles do
		local fstart = time.now()
		local success, err = pcall(luau.loadModule, p, nil)
		local elapsed = time.since(fstart)

		if not success then
			print(`Error loading {path.format(p)}: {err}`)
			ps.exit(1)
		end

		table.insert(perfile, { file = path.format(p), seconds = elapsed })
	end

	return {
		totalseconds = time.since(loadstart),
		count = #testfiles,
		perfile = perfile,
	}
end

local function printLoadSummary(stats: LoadStats, discoverSeconds: number, discoveredCount: number)
	print(
		`Discovered {discoveredCount} test files in {formatSeconds(discoverSeconds)}; `
			.. `loaded {stats.count} in {formatSeconds(stats.totalseconds)}`
	)

	local perfile = table.clone(stats.perfile)
	table.sort(perfile, function(a, b)
		return a.seconds > b.seconds
	end)

	local slow = {}
	for _, entry in perfile do
		if entry.seconds < SLOW_LOAD_THRESHOLD_SECONDS then
			break
		end
		table.insert(slow, entry)
		if #slow >= SLOW_LOAD_LIMIT then
			break
		end
	end

	if #slow > 0 then
		print("Slowest test file loads:")
		for _, entry in slow do
			print(`  {formatSeconds(entry.seconds)}  {entry.file}`)
		end
	end
end

local function listtests()
	-- Gets all registered tests using the shared test instance
	local registered = test._registered()

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

local function runtests(
	env: testtypes.TestEnvironment,
	runFn: (testtypes.TestEnvironment) -> testtypes.TestRunResult,
	reporter: testtypes.TestReporter,
	afterRun: (() -> ())?
)
	local result = runFn(env)

	reporter(result)
	if afterRun then
		afterRun()
	end
	if result.failed ~= 0 then
		ps.exit(1)
	end
	ps.exit(0)
end

local function runsnapshots(searchpaths: { string }, update: boolean, interactive: boolean)
	local files = finder.findsnapfiles(searchpaths)

	if #files == 0 then
		print("No snapshot files (*.snap.luau) found.")
		ps.exit(0)
		return
	end

	local result = snaprunner.runsnapshots(files)
	reporter.snap(result)
	updater.updatesnapshot(result, update, interactive)
end

local function main(...: string)
	local args = cli.parser()

	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("list", "flag", { help = "List all discovered test cases without running them" })
	args:add("suite", "option", { help = "Run only tests in the specified suite", aliases = { "s" } })
	args:add("case", "option", { help = "Run only test cases matching the specified name", aliases = { "c" } })
	args:add("interactive", "flag", { help = "Interactively accept/reject snapshot changes", aliases = { "i" } })
	args:add("update", "flag", { help = "Auto-accept all snapshot changes", aliases = { "u" } })
	args:add("parallel-suites", "option", {
		help = "Run up to N suites concurrently (default 1, sequential).",
		aliases = { "p" },
	})

	args:parse({ ... })

	if args:has("help") then
		print(args:help())
		return
	end

	local forwarded = args:forwarded()
	-- Check if this is a snapshot subcommand
	if forwarded and #forwarded > 0 and forwarded[1] == "snapshots" then
		if #forwarded == 1 then
			runsnapshots({ "./tests" }, args:has("update"), args:has("interactive"))
		else
			local searchpaths = {}
			for idx = 2, #forwarded do
				table.insert(searchpaths, forwarded[idx])
			end
			runsnapshots(searchpaths, args:has("update"), args:has("interactive"))
		end
	end

	local searchpath = if forwarded and #forwarded > 0 then forwarded else { "./" }
	local isList = args:has("list")

	local phaseStart = time.now()

	local discoverstart = time.now()
	local testfiles, walkStats = finder.findtestfiles(searchpath)
	local discoverSeconds = time.since(discoverstart)

	local stats = loadtests(testfiles)

	if isList then
		-- --list output is consumed by other tests verbatim; keep stdout clean.
		listtests()
	else
		printLoadSummary(stats, discoverSeconds, #testfiles)
		print(`Discovery walk: {walkStats.entriesVisited} filesystem entries visited`)
		local env = test._registered() :: testtypes.TestEnvironment
		local filteredEnv = filter.filtertests(env, args:get("suite"), args:get("case"))
		local setupSeconds = time.since(phaseStart)

		local parallelSuitesArg = args:get("parallel-suites")
		local parallelSuites = if parallelSuitesArg then tonumber(parallelSuitesArg) else 8
		if parallelSuitesArg and not parallelSuites then
			print(`Invalid --parallel-suites value: '{parallelSuitesArg}' (expected a number)`)
			ps.exit(1)
		end

		local function runFn(e: testtypes.TestEnvironment): testtypes.TestRunResult
			return runner.run(e, { parallelSuites = parallelSuites })
		end

		runtests(filteredEnv, runFn, reporter.color, function()
			print(
				`Phase timings: discover={formatSeconds(discoverSeconds)}, `
					.. `load={formatSeconds(stats.totalseconds)}, `
					.. `cli-setup(total before runner)={formatSeconds(setupSeconds)}`
			)
		end)
	end
end

main(...)
