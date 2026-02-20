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
local snaprunner = require("@self/snap/runner")
local updater = require("@self/snap/updater")

local function loadtests(testfiles: { path.path })
	-- Load all test files first
	for _, p in testfiles do
		local success, err = pcall(luau.loadbypath, p, nil)

		if not success then
			print(`Error loading {path.format(p)}: {err}`)
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

local function runtests(env: testtypes.testenvironment, runner: testtypes.testrunner, reporter: testtypes.testreporter)
	local result = runner(env)

	reporter(result)
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

	local searchpath = if forwarded and #forwarded > 0 then forwarded else { "./tests" }
	loadtests(finder.findtestfiles(searchpath))

	if args:has("list") then
		listtests()
	else
		local env = test._registered() :: testtypes.testenvironment
		local filteredEnv = filter.filtertests(env, args:get("suite"), args:get("case"))
		runtests(filteredEnv, runner.run, reporter.color)
	end
end

main(...)
