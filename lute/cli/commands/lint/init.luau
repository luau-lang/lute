local cli = require("./cli")
local fs = require("@std/fs")
local luau = require("@std/luau")
local pathLib = require("@std/path")
local printer = require("@self/printer")
local syntax = require("@std/syntax")
local tableext = require("@std/tableext")
local types = require("@self/types")

local USAGE = "Usage: lute lint [OPTIONS] [...PATHS]"

local function printHelp()
	print(USAGE)
	print([[
Lint the specified Luau file using the specified lint rule(s).

OPTIONS:
  -h, --help              Show this help message
  -r, --rules [RULE]      Path to a single lint rule or a folder containing lint rules. If a folder is provided, any subfolders containing init.luau files will be treated as modules exporting lint rules, while all other .luau files will be treated as individual lint rules.

PATHS:
  Path(s) to the Luau file(s) or folders containing Luau files to be linted.

EXAMPLES:
  lute lint -r examples/lints/almost_swapped.luau bad_swap.luau
  lute lint -r examples/lints/ lintee.luau src_code/
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

local function lintFile(inputFilePath: pathLib.path, lintRules: { types.LintRule }): { types.LintViolation }
	print(`Reading input file '{inputFilePath}'`)
	local fileContent = fs.readfiletostring(inputFilePath)

	print(`Parsing input file '{inputFilePath}'`)
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

	return violations
end

local function main(...: string)
	local args = cli.parser()

	args:add("rules", "option", { help = "Linting rule(s) to apply", aliases = { "r" } })
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

	local inputFiles = args:forwarded()
	if inputFiles == nil or #inputFiles == 0 then
		print("Error: No input files specified.\n\n" .. USAGE .. "\nUse --help for more information.")
		return
	end

	print(`Loading lint rule(s) from '{rulePath}'`)
	local lintRules = loadLintRules(rulePath)

	local allViolations = {}

	for _, inputPath in inputFiles do
		local walker = fs.walk(inputPath, { recursive = true })

		local curr = walker()
		while curr ~= nil do
			local inputFilePath = pathLib.parse(curr)

			if pathLib.extname(inputFilePath) == ".luau" then
				local success, err = pcall(lintFile, inputFilePath, lintRules)
				if success then
					-- Violations are returned as the second return value from pcall
					allViolations[inputFilePath] = err
				else
					print(`Error linting file '{inputFilePath}': {err}`)
				end
			else
				print(`Skipping non-Luau file '{inputFilePath}'`)
			end

			curr = walker()
		end
	end

	print(`Printing violations from {#allViolations} files\n`)
	for sourcePath, violations in allViolations do
		if #violations > 0 then
			printer.printLints(violations, sourcePath)
		end
	end
end

main(...)
