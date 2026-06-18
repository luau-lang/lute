local cli = require("@batteries/cli")
local files = require("./lib/files")
local internalTypes = require("@self/internaltypes")
local json = require("@std/json")
local lint = require("@self/lint")
local lintCore = require("@self/lintCore")
local lsp = require("@self/lsp")
local parseIgnores = require("./lib/parseIgnores")
local pathLib = require("@std/path")
local printer = require("@self/printer")
local process = require("@std/process")
local tableext = require("@std/tableext")
local types = require("@lint")

local USAGE = "Usage: lute lint [OPTIONS] [...PATHS]"
local VERBOSE = false
local SEQUENTIAL = false

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
  --sequential			  Lint files sequentially. Files are linted in parallel by default.

PATHS:
  Path(s) to the Luau file(s) or folders containing Luau files to be linted. Only files with .luau or .lua extensions will be linted.

EXAMPLES:
  lute lint -r examples/lints/almost_swapped.luau bad_swap.luau
  lute lint -r examples/lints/ lintee.luau src_code/
]])
end

local lintString = lintCore.lintString

type Job = {
	inputFile: pathLib.Path,
	autoFixEnabled: boolean,
}

local function lintPaths(
	inputFilePaths: { string },
	lintRules: { types.LintRule },
	configData: internalTypes.RuleConfigData,
	rulesPath: string?,
	noDefaults: boolean,
	passedConfigVal: string?,
	autofixEnabled: boolean,
	ignoreData: parseIgnores.GitignoreData
): { [pathLib.Path]: { types.LintViolation } }
	if VERBOSE then
		print("Filtering input files by gitignore")
	end
	local inputFiles = files.getSourceFiles(inputFilePaths, VERBOSE)

	if SEQUENTIAL then
		return lint.lintSequential(inputFiles, lintRules, configData, autofixEnabled, ignoreData, VERBOSE)
	end

	return lint.lintParallel(inputFiles, rulesPath, noDefaults, passedConfigVal, autofixEnabled, ignoreData, VERBOSE)
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
	args:add("sequential", "flag", { help = "Lint files sequentially (parallel by default)" })

	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	VERBOSE = args:has("verbose")
	SEQUENTIAL = args:has("sequential")

	local inputFiles = args:forwarded()
	local stringInput = args:get("string-input")
	if (inputFiles == nil or #inputFiles == 0) and not stringInput then
		inputFiles = { pathLib.format(process.cwd()) }
	end

	local passedConfigVal = args:get("config")
	local noDefaultLints = args:has("no-default-lints")
	local rulesPath = args:get("rules")

	local lintRules, configContextData, ignoreData =
		lintCore.initialize(passedConfigVal, noDefaultLints, rulesPath, VERBOSE)

	if stringInput ~= nil then
		if args:has("auto-fix") then
			print("Auto-fix has no effect on string input.")
		end

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

		local allViolations = lintPaths(
			inputFiles :: { string },
			lintRules,
			configContextData,
			rulesPath,
			noDefaultLints,
			passedConfigVal,
			autofixEnabled,
			ignoreData
		)

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
