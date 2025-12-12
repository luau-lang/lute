local cli = require("./lib/cli")
local files = require("./lib/files")
local fs = require("@std/fs")
local json = require("@std/json")
local lsp = require("@self/lsp")
local luau = require("@std/luau")
local pathLib = require("@std/path")
local printer = require("@self/printer")
local process = require("@std/process")
local syntax = require("@std/syntax")
local tableext = require("@std/tableext")
local triviaUtils = require("@std/syntax/utils/trivia")
local types = require("@self/types")
local visitor = require("@std/syntax/visitor")

local DEFAULT_RULES = { "almost_swapped", "divide_by_zero" }
local USAGE = "Usage: lute lint [OPTIONS] [...PATHS]"
local VERBOSE = false

local function printHelp()
	print(USAGE)
	print([[
Lint the specified Luau file using the specified lint rule(s) or using the default rules.

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose		  	  Enable verbose output
  -r, --rules [RULE]      Path to a single lint rule or a folder containing lint rules. If a folder 
  						  is provided, any subfolders containing init.luau files will be treated as
						  modules exporting lint rules, while all other .luau files will be treated 
						  as individual lint rules. If unspecified, the default lint rules are used.
  -j, --json              Output lint violations in JSON format matching the LSP diagnostic spec.

PATHS:
  Path(s) to the Luau file(s) or folders containing Luau files to be linted. Only files with .luau or .lua extensions will be linted.

EXAMPLES:
  lute lint -r examples/lints/almost_swapped.luau bad_swap.luau
  lute lint -r examples/lints/ lintee.luau src_code/
]])
end

local function assertIsLintRule(rule: unknown, path: string)
	assert(rule, `{path} failed to require`)
	assert(typeof(rule) == "table", `{path} must return a table`)
	assert(typeof(rule.name) == "string", `{path} must return a table with a 'name' string property`)
	assert(
		typeof(rule.lint) == "function", -- LUAUFIX: type error on loaded.lint because loaded has been refined to { read name: string }
		`{path} must return a table with a 'lint' function property`
	)
end

local function loadLintRule(path: string): types.LintRule
	local loaded = luau.loadbypath(path)
	assertIsLintRule(loaded, path)

	return loaded -- Typecast isn't needed because loaded is refined to any bc of type error in assertIsLintRule
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

local function loadDefaultRules(): { types.LintRule }
	local rules = {}
	for _, ruleName in DEFAULT_RULES do
		local path = `@self/rules/{ruleName}`
		local rule: types.LintRule = require(path) :: any -- Anycast to silence error from dynamic require
		assertIsLintRule(rule, path)
		table.insert(rules, rule)
	end
	return rules
end

local function parseDirectives(node: syntax.AstNode): { [string]: boolean }
	local directives: { [string]: boolean } = {}

	local leadingTrivia = triviaUtils.leftmosttrivia(node)
	for _, trivia in leadingTrivia do
		if trivia.tag == "blockcomment" or trivia.tag == "comment" then
			for rule in trivia.text:gmatch("lute%-lint%-ignore%((.+)%)") do
				directives[rule] = true -- True means ignore
			end
			for rule in trivia.text:gmatch("lute%-lint%-report%((.+)%)") do
				directives[rule] = false -- False means report
			end
		end
	end

	return directives
end

local function maybeParseDirectives(
	node: syntax.AstNode,
	cache: { [syntax.AstNode]: { [string]: boolean } }
): { [string]: boolean }
	local directives = cache[node]
	if directives == nil then
		directives = parseDirectives(node)

		if node.kind == "stat" and node.tag == "block" then
			-- The logic here is a little different, since we only want suppression to apply to the first statement
			-- Store a sentinel value at this node to avoid reparsing suppressions
			cache[node] = {}
			-- Parse the rules that this node suppresses and attach them to the first statement of the block
			cache[node.statements[1]] = directives
		end

		cache[node] = directives
	end
	return directives
end

local function violationIsSuppressed(
	violation: types.LintViolation,
	ast: syntax.AstStatBlock,
	directiveCache: { [syntax.AstNode]: { [string]: boolean } },
	globalIgnores: { [string]: true }
): boolean
	local violationSuppressed = globalIgnores[violation.lintname] == true

	-- We want to find the lint directive with the tightest scope that applies to this violation
	local function nodeIsSuppressed(node: syntax.AstNode): boolean
		if syntax.span.subsumes(violation.location, node.location) then
			-- The first node which is fully contained within a violation has the tightest relevant directive
			local directives = maybeParseDirectives(node, directiveCache)
			violationSuppressed = if directives[violation.lintname] ~= nil
				then directives[violation.lintname]
				else violationSuppressed
			-- No other fully contained nodes can affect whether we suppress, so we can stop recursing
			return false
		end

		if not syntax.span.subsumes(node.location, violation.location) then
			-- Violation doesn't come from this node, so don't recurse deeper
			return false
		end

		local directives = maybeParseDirectives(node, directiveCache)

		-- AstStatBlock suppressions should only apply to the first statement, not the block itself
		if node.kind == "stat" and node.tag == "block" then
			return true
		end

		-- Use any directives found on this node to update suppression status
		violationSuppressed = if directives[violation.lintname] ~= nil
			then directives[violation.lintname]
			else violationSuppressed

		-- A deeper node might affect whether we suppress, so continue recursing
		return true
	end

	local suppressionVisitor = visitor.create(nodeIsSuppressed)

	visitor.visitblock(ast, suppressionVisitor)

	return violationSuppressed
end

local function parseGlobalIgnores(trivia: { syntax.Trivia }): { [string]: true }
	local globalIgnores: { [string]: true } = {}

	for _, triv in trivia do
		if triv.tag == "blockcomment" or triv.tag == "comment" then
			for rule in triv.text:gmatch("lute%-lint%-global%-ignore%((.+)%)") do
				globalIgnores[rule] = true
			end
		end
	end

	return globalIgnores
end

local function lintFile(inputFilePath: pathLib.path, lintRules: { types.LintRule }): { types.LintViolation }
	if VERBOSE then
		print(`Reading input file '{inputFilePath}'`)
	end
	local fileContent = fs.readfiletostring(inputFilePath)

	if VERBOSE then
		print(`Parsing input file '{inputFilePath}'`)
	end
	local ast = syntax.parseblock(fileContent)

	if VERBOSE then
		print(`Parsing global lint ignores in '{inputFilePath}'`)
	end
	local globalIgnores = parseGlobalIgnores(triviaUtils.leftmosttrivia(ast))

	if VERBOSE then
		print("Applying lint rules")
	end
	local violations: { types.LintViolation } = {}
	local directiveCache = {}
	for _, rule in lintRules do
		local success, err = pcall(rule.lint, ast, inputFilePath)
		if success then
			-- On success, err contains the returned violations
			for _, violation in err do
				if not violationIsSuppressed(violation, ast, directiveCache, globalIgnores) then
					table.insert(violations, violation)
				end
			end
		else
			print(`Error applying lint rule '{rule.name}': {err}`)
		end
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
	args:add("verbose", "flag", { help = "Enable verbose output", aliases = { "v" } })
	args:add("json", "flag", { help = "Output lint violations in JSON format", aliases = { "j" } })
	-- TODO: ignore blobs

	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	VERBOSE = args:has("verbose")

	local inputFiles = args:forwarded()
	if inputFiles == nil or #inputFiles == 0 then
		print("Error: No input files specified.\n\n" .. USAGE .. "\nUse --help for more information.")
		process.exit(1)
	end

	if VERBOSE then
		print("Filtering input files by gitignore")
	end
	local inputFilePaths = files.getSourceFiles(inputFiles, VERBOSE)

	local lintRules: { types.LintRule }
	local rulePath = args:get("rules")
	if rulePath == nil then
		if VERBOSE then
			print("Using default lint rules.")
		end
		lintRules = loadDefaultRules()
	else
		if VERBOSE then
			print(`Loading lint rule(s) from '{rulePath}'`)
		end
		lintRules = loadLintRules(rulePath)
	end

	local allViolations: { [pathLib.path]: { types.LintViolation } } = {}

	for _, inputPath in inputFilePaths do
		local walker = fs.walk(inputPath, { recursive = true })

		local curr = walker()
		while curr ~= nil do
			local inputFilePath = pathLib.parse(curr)

			local success, err = pcall(lintFile, inputFilePath, lintRules)
			if success then
				-- Violations are returned as the second return value from pcall
				allViolations[inputFilePath] = err
			else
				print(`Error linting file '{inputFilePath}': {err}`)
			end

			curr = walker()
		end
	end

	if args:has("json") then
		print(json.serialize(lsp.workspaceDiagnosticReport(allViolations) :: json.object, true))
	else
		if VERBOSE then
			print(`Printing violations from {#allViolations} files\n`)
		end
		local violationsFound = false
		for sourcePath, violations in allViolations do
			if #violations > 0 then
				violationsFound = true
				printer.printLints(violations, sourcePath)
			end
		end
		process.exit(if violationsFound then 1 else 0)
	end
end

main(...)
