local cli = require("@batteries/cli")
local files = require("./lib/files")
local fs = require("@std/fs")
local json = require("@std/json")
local lsp = require("@self/lsp")
local pathLib = require("@std/path")
local printer = require("@self/printer")
local process = require("@std/process")
local tableext = require("@std/tableext")
local types = require("@self/types")
local parseIgnores = require("./lib/parseIgnores")
local lintCore = require("@self/lintCore")
local task = require("@std/task")
local system = require("@std/system")
local vm = require("@lute/vm")

local USAGE = "Usage: lute lint [OPTIONS] [...PATHS]"
local VERBOSE = false

local function printHelp()
	print(USAGE)
	-- Ordering of options: help + verbose fist, then options with aliases in alphabetical order, then options without aliases in alphabetical order
	print([[
Lint the specified Luau file using the specified lint rule(s) or using the default rules.

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose		  	  Enable verbose output
  -c, --config [PATH]	  Path to configuration file. By default, lute lint will look for a
  						  the .config.luau file in the calling directory.
  -j, --json              Output lint violations in JSON format matching the LSP diagnostic spec.
  -r, --rules [RULE]      Path to a single lint rule or a folder containing lint rules. If a folder 
  						  is provided, any subfolders containing init.luau files will be treated as
						  modules exporting lint rules, while all other .luau files will be treated 
						  as individual lint rules. If unspecified, the default lint rules are used.
  -s, --string-input	  Lint the provided string input instead of reading from files.
  --auto-fix			  Automatically apply fixes for lint violations that provide a suggested fix.
						  Assumes that suggested fixes do not overlap.
  --no-default-lints	  Disables the default lint rules.

PATHS:
  Path(s) to the Luau file(s) or folders containing Luau files to be linted. Only files with .luau or .lua extensions will be linted.

EXAMPLES:
  lute lint -r examples/lints/almost_swapped.luau bad_swap.luau
  lute lint -r examples/lints/ lintee.luau src_code/
]])
end

local lintString = lintCore.lintString

type fix = types.fix

type Job = {
	inputFile: pathLib.Path,
	autoFixEnabled: boolean,
}

local function lintPaths(
	inputFilePaths: { string },
	rulePath: string?,
	noDefaults: boolean,
	passedConfigVal: string?,
	autofixEnabled: boolean,
	ignoreData: parseIgnores.GitignoreData
): { [pathLib.Path]: { types.LintViolation } }
	if VERBOSE then
		print("Filtering input files by gitignore")
	end
	local inputFiles = files.getSourceFiles(inputFilePaths, VERBOSE)

	local allViolations: { [pathLib.Path]: { types.LintViolation } } = {}
	local hasIgnores = #ignoreData.ignores > 0

	local maxWorkers = math.min(system.threadCount(), #inputFiles)
	local curJob = 1
	local doneWorkers = 0

	local function lintNext(): Job?
		if curJob > #inputFiles then
			return nil
		end

		local nextJob: Job = {
			inputFile = inputFiles[curJob],
			autoFixEnabled = autofixEnabled,
		}

		curJob += 1

		return nextJob
	end

	local function spawnWorker()
		task.spawn(function()
			xpcall(function()
				local lintFile = vm.create("@self/lintFile")
				lintFile.initialize({
					rulePath = rulePath,
					noDefaults = noDefaults,
					configPath = passedConfigVal,
					verbose = VERBOSE,
				})

				local curJob = lintNext()
				while curJob ~= nil do
					local job = curJob :: Job

					local walker = fs.walk(job.inputFile, { recursive = true })

					local curr = walker()
					while curr ~= nil do
						if hasIgnores then
							local inputFilePathString = pathLib.format(curr)

							if
								parseIgnores.isIgnored(
									ignoreData,
									inputFilePathString,
									fs.type(inputFilePathString) == "dir"
								)
							then
								curr = walker()
								continue
							end
						end

						local success, res = pcall(function()
							return lintFile.lintFile({
								file = pathLib.format(curr :: pathLib.Path),
								autofix = job.autoFixEnabled,
								verbose = VERBOSE,
							})
						end)
						if success then
							allViolations[curr] = res :: { types.LintViolation }
						else
							print(`(worker) Error linting file '{curr}': {res}`)
						end

						curr = walker()
					end
					curJob = lintNext()
				end
			end, function(err: any)
				print(`worker errored: {tostring(err)}`)
			end)

			doneWorkers += 1
		end)
	end

	for _ = 1, maxWorkers do
		spawnWorker()
	end

	while doneWorkers < maxWorkers do
		task.wait() -- wait for all jobs to run
	end

	return allViolations
end

local function main(...: string)
	local args = cli.parser()

	args:add(
		"auto-fix",
		"flag",
		{ help = "Automatically apply fixes for lint violations that provide a suggested fix" }
	)
	args:add("config", "option", { help = "Path to configuration file", aliases = { "c" } })
	args:add("help", "flag", { help = "Show help message", aliases = { "h" } })
	args:add("json", "flag", { help = "Output lint violations in JSON format", aliases = { "j" } })
	args:add("no-default-lints", "flag", { help = "Disables the default lint rules" })
	args:add("rules", "option", { help = "Linting rule(s) to apply", aliases = { "r" } })
	args:add(
		"string-input",
		"option",
		{ help = "Lint the provided string input instead of reading from files", aliases = { "s" } }
	)
	args:add("verbose", "flag", { help = "Enable verbose output", aliases = { "v" } })

	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	VERBOSE = args:has("verbose")

	local inputFiles = args:forwarded()
	local stringInput = args:get("string-input")
	if (inputFiles == nil or #inputFiles == 0) and not stringInput then
		inputFiles = { pathLib.format(process.cwd()) }
	end

	local passedConfigVal = args:get("config")
	local noDefaultLints = args:has("no-default-lints")
	local rulePath = args:get("rules")

	local lintConfig = lintCore.loadConfig(passedConfigVal, VERBOSE)

	local ignores = if lintConfig.ignores ~= nil then lintConfig.ignores else {}
	local configPath: pathLib.Pathlike = if passedConfigVal
		then passedConfigVal
		else pathLib.join(process.cwd(), ".config.luau")
	local rootLocation = if fs.exists(configPath)
		then pathLib.format(pathLib.resolve(pathLib.dirname(configPath)))
		else pathLib.format(process.cwd())
	local ignoreData = parseIgnores.parseIgnoreContents(rootLocation, ignores)

	if stringInput ~= nil then
		if args:has("auto-fix") then
			print("Auto-fix has no effect on string input.")
		end

		local lintData = lintCore.initialize(passedConfigVal, noDefaultLints, rulePath, VERBOSE)

		local lintRules, configContextData = lintData.lintRules, lintData.configContextData

		local violations = lintString(stringInput, lintRules, nil, configContextData, VERBOSE)

		if args:has("json") then
			local diagnostics = tableext.map(violations, lsp.diagnostic)
			print(json.serialize(diagnostics :: json.Array, true))
		elseif #violations > 0 then
			if VERBOSE then
				print(`Printing violations from string input\n`)
			end

			printer.printLintsWithSource(violations, stringInput)

			process.exit(1)
		else
			if VERBOSE then
				print("No lint violations found.")
			end

			process.exit(0)
		end
	else
		local autofixEnabled = args:has("auto-fix")
		if autofixEnabled and VERBOSE then
			print("Auto-fix is enabled.")
		end

		local allViolations =
			lintPaths(inputFiles :: { string }, rulePath, noDefaultLints, passedConfigVal, autofixEnabled, ignoreData) -- LUAUFIX: type refinement on line 305 should mean that cast on inputFiles isn't needed

		if args:has("json") then
			print(json.serialize(lsp.workspaceDiagnosticReport(allViolations) :: json.Object, true))
		else
			if VERBOSE then
				print(`Printing violations from {#allViolations} files\n`)
			end

			local violationsFound = false

			for sourcePath, violations in allViolations do
				if #violations > 0 then
					violationsFound = true
					printer.printLintsWithPath(violations, sourcePath)
				end
			end

			process.exit(if violationsFound then 1 else 0)
		end
	end
end

main(...)
