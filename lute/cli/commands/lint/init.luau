local cli = require("./cli")
local fs = require("@std/fs")
local luau = require("@std/luau")
local pathLib = require("@std/path")
local printer = require("@self/printer")
local syntax = require("@std/syntax")
local tableext = require("@std/tableext")
local types = require("@self/types")

local USAGE = "Usage: lute lint [OPTIONS] [PATH]"

local function printHelp()
	print(USAGE)
	print([[
Lint the specified Luau file using the specified lint rule(s).

OPTIONS:
  -h, --help              Show this help message
  -r, --rules [RULE]      Path to a single lint rule or a folder containing lint rules. If a folder is provided, all .luau files will be assumed to be lint rules.

PATH:
  Path to the Luau file to be linted.

EXAMPLES:
  lute lint -r examples/lints/almost_swapped.luau bad_swap.luau
  lute lint -r examples/lints/ lintee.luau
]])
end

local function loadLintRule(path: string): types.LintRule
	local loaded = luau.loadbypath(path)
	assert(loaded, `{path} failed to require`)
	assert(typeof(loaded) == "table", `{path} must return a table`)
	assert(typeof(loaded.name) == "string", `{path} must return a table with a 'name' string property`)
	assert(
		typeof(loaded.lint) == "function", -- LUAUFIX: type error on loaded.lint because loaded has been refined to { read name: string }
		`{path} must return a table with a 'lint' function property`
	)

	return loaded :: types.LintRule -- We have to cast because we can't assert that loaded.lint is a more specific function type
end

local function loadLintRules(path: string): { types.LintRule }
	assert(fs.exists(path), `Lint rule at path '{path}' does not exist`)

	if fs.metadata(path).type == "dir" then
		local rules = {}

		local walker = fs.walk(path, { recursive = true })
		local curr = walker()

		while curr ~= nil do
			if pathLib.extname(curr) == ".luau" then
				table.insert(rules, loadLintRule(pathLib.format(curr)))
			end

			curr = walker()
		end

		return rules
	else
		return { loadLintRule(path) }
	end
end

local function main(...: string)
	local args = cli.parser()

	args:add("rules", "option", { help = "Linting rule(s) to apply", aliases = { "r" } })
	args:add("input", "positional", { help = "Input file to be linted" })
	args:add("help", "flag", { help = "Show help message", aliases = { "h" } })
	-- TODO: handle multiple rules, multiple input files, ignore blobs, json output option

	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	local rulePath = args:get("rules")
	if rulePath == nil then
		-- TODO: support default rules
		print("Error: No lint rules specified.\n\n" .. USAGE .. "\nUse --help for more information.")
		return
	end

	local inputFile = args:get("input")
	if inputFile == nil then
		print("Error: No input file specified.\n\n" .. USAGE .. "\nUse --help for more information.")
		return
	end
	local inputFilePath = pathLib.parse(inputFile)

	print(`Loading lint rule(s) from '{rulePath}'`)
	local lintRules = loadLintRules(rulePath)

	print(`Reading input file '{inputFile}'`)
	local fileContent = fs.readfiletostring(inputFilePath)

	print(`Parsing input file '{inputFile}'`)
	local ast = syntax.parseblock(fileContent)

	print("Applying lint rules")
	local violations: { types.LintViolation } = {}
	for _, rule in lintRules do
		tableext.extend(violations, rule.lint(ast, inputFilePath))
	end
	table.sort(
		violations,
		function(a: types.LintViolation, b: types.LintViolation) -- LUAUFIX: bidirecitonal inference should mean that annotations on a and b aren't needed
		return a.location < b.location
		end
	)

	print(`Printing {#violations} violations\n`)
	printer.printLints(violations, fileContent)
end

main(...)
