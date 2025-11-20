local cli = require("./cli")
local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local printer = require("@self/printer")
local syntax = require("@std/syntax")
local types = require("@self/types")

local USAGE = "Usage: lute lint [OPTIONS] [RULE] [PATH]"

local function printHelp()
	print(USAGE)
	print([[
Lint the specified Luau file using the specified lint rule.

OPTIONS:
  -h, --help              Show this help message

RULE:
  Path to a Luau file defining a lint rule.

PATH:
  Path to the Luau file to be linted.

EXAMPLES:
  lute lint examples/lints/almost_swapped.luau bad_swap.luau
]])
end

local function loadLintRule(path: path.pathlike): types.LintRule
	local loaded = luau.loadbypath(path)
	assert(loaded, `{path} failed to require`)
	assert(typeof(loaded) == "table", `{path} must return a table`)
	assert(typeof(loaded.name) == "string", `{path} must return a table with a 'name' string property`)
	assert(
		typeof(loaded.lint) == "function", -- LUAUFIX: type error on loaded.lint because loaded has been refined to { read name: string }
		`{path} must return a table with a 'lint' function property`
	)

	return loaded :: types.LintRule -- We have to cast because we can't assert that loaded.lint is a more specific functio type
end

local function main(...: string)
	local args = cli.parser()

	args:add("rule", "positional", { help = "Linting rule to apply" })
	args:add("input", "positional", { help = "Input file to be linted" })
	args:add("help", "flag", { help = "Show help message", aliases = { "h" } })
	-- TODO: handle multiple rules, multiple input files, ignore blobs, json output option

	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	local rulePath = args:get("rule")
	if rulePath == nil then
		print("Error: No lint rule specified.\n\n" .. USAGE .. "\nUse --help for more information.")
		return
	end

	local inputFile = args:get("input")
	if inputFile == nil then
		print("Error: No input file specified.\n\n" .. USAGE .. "\nUse --help for more information.")
		return
	end
	local inputFilePath = path.parse(inputFile)

	print(`Loading lint rule from '{rulePath}'`)
	local lintRule = loadLintRule(rulePath)

	print(`Reading input file '{inputFile}'`)
	local fileContent = fs.readfiletostring(inputFilePath)

	print(`Parsing input file '{inputFile}'`)
	local ast = syntax.parseblock(fileContent)

	print("Applying lint rule")
	local violations = lintRule.lint(ast, inputFilePath)

	print(`Printing {#violations} violations\n`)
	printer.printLints(violations, fileContent)
end

main(...)
