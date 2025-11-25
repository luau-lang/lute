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
  -r, --rules [RULE]      Path to a single lint rule or a folder containing lint rules. If a folder is provided, any subfolders containing init.luau files will be treated as modules exporting lint rules, while all other .luau files will be treated as individual lint rules.

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

	return loaded :: types.LintRule -- We have to cast because we can only assert that loaded.lint is the top function type, rather than a more specific function type like (ast: syntax.AstStatBlock, sourcepath: path.path) -> { LintViolation }
end

local function loadLintRules(path: string): { types.LintRule }
	assert(fs.exists(path), `Lint rule at path '{path}' does not exist`)

	local rules = {}

	local queue: { string } = { path }
	while #queue > 0 do
		local currentPath = table.remove(queue, 1)
		assert(currentPath, "We should never pop from an empty queue")

		if fs.metadata(currentPath).type == "dir" then
			local currentPathObj = pathLib.parse(currentPath)
			local initPath = pathLib.format(pathLib.join(currentPathObj, "init.luau"))
			if fs.exists(initPath) then
				table.insert(rules, loadLintRule(initPath))
			else
				local entries = fs.listdirectory(currentPath)
				local childPaths = tableext.map(entries, function(entry)
					return pathLib.format(pathLib.join(currentPathObj, entry.name))
				end)
				tableext.extend(queue, childPaths)
			end
		elseif pathLib.extname(currentPath) == ".luau" then
			table.insert(rules, loadLintRule(currentPath))
		end
	end

	return rules
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
		local success, err = pcall(rule.lint, ast, inputFilePath)
		if success then
			-- On success, err contains the returned violations
			tableext.extend(violations, err)
		else
			print(`Error applying lint rule '{rule.name}': {err}`)
		end
	end
	table.sort(
		violations,
		function(a: types.LintViolation, b: types.LintViolation) -- LUAUFIX: bidirectional inference should mean that annotations on a and b aren't needed
			return a.location < b.location
		end
	)

	print(`Printing {#violations} violations\n`)
	printer.printLints(violations, fileContent)
end

main(...)
