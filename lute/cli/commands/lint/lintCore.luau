local fs = require("@std/fs")
local internalTypes = require("./internaltypes")
local luau = require("@std/luau")
local pathLib = require("@std/path")
local process = require("@std/process")
local syntax = require("@std/syntax")
local tableext = require("@std/tableext")
local triviaUtils = require("@std/syntax/utils/trivia")
local types = require("./types")
local visitor = require("@std/syntax/visitor")
local configUtils = require("./configutils")
local parseIgnores = require("../lib/parseIgnores")

local DEFAULT_RULES = {
	"almost_swapped",
	"constant_table_comparison",
	"divide_by_zero",
	"duplicate_keys",
	"empty_if_block",
	"global_function_in_scope",
	"parenthesized_conditions",
	"unused_variable",
}

local function isLintRule(rule: unknown, path: string, VERBOSE: boolean): boolean
	if not rule then
		if VERBOSE then
			print(`Error loading lint rule from {path}: failed to require`)
		end
		return false
	end

	if typeof(rule) ~= "table" then
		if VERBOSE then
			print(`Error loading lint rule from {path}: must return a table`)
		end
		return false
	end

	if typeof(rule.name) ~= "string" then
		if VERBOSE then
			print(`Error loading lint rule from {path}: must return a table with a 'name' string property`)
		end
		return false
	end

	if typeof((rule :: { lint: unknown }).lint) ~= "function" then -- LUAUFIX: rule got refined to { read name : string } so accessing prop lint errors
		if VERBOSE then
			print(`Error loading lint rule from {path}: must return a table with a 'lint' function property`)
		end
		return false
	end

	return true
end

local function loadLintRule(path: string, VERBOSE: boolean): types.LintRule?
	local loaded = luau.loadModule(path)
	return if isLintRule(loaded, path, VERBOSE) then loaded else nil -- Typecast isn't needed because loaded is refined to any bc of type error in isLintRule
end

local function registerRule(
	rule: types.LintRule,
	config: internalTypes.LintConfig,
	rootLocation: string,
	rules: { types.LintRule },
	ruleConfigs: internalTypes.RuleConfigurations,
	ruleIgnores: internalTypes.RuleIgnores
)
	local ruleConfig: internalTypes.RuleConfig = if config.ruleconfigs ~= nil
		then config.ruleconfigs[rule.name] or {}
		else {}
	if ruleConfig.off then
		return
	end

	table.insert(rules, rule)
	ruleConfigs[rule.name] = ruleConfig
	if ruleConfig.ignores ~= nil then
		ruleIgnores[rule.name] = parseIgnores.parseIgnoreContents(rootLocation, ruleConfig.ignores)
	end
end

local function loadLintRules(
	path: string,
	config: internalTypes.LintConfig,
	rootLocation: string,
	VERBOSE: boolean
): ({ types.LintRule }, internalTypes.RuleConfigurations, internalTypes.RuleIgnores)
	assert(fs.exists(path), `Lint rule at path '{path}' does not exist`)

	local rules, ruleConfigs: internalTypes.RuleConfigurations, ruleIgnores = {}, {}, {}

	local queue: { string } = { path }
	while #queue > 0 do
		local currentPath = table.remove(queue, 1)
		assert(currentPath, "We should never pop from an empty queue")

		if fs.metadata(currentPath).type == "dir" then
			local currentPathObj = pathLib.parse(currentPath)
			local initPath = pathLib.format(pathLib.join(currentPathObj, "init.luau"))
			if fs.exists(initPath) then
				local rule = loadLintRule(initPath, VERBOSE)
				if rule then
					registerRule(rule, config, rootLocation, rules, ruleConfigs, ruleIgnores)
				end
			else
				local entries = fs.listDirectory(currentPath)
				local childPaths = tableext.map(entries, function(entry)
					return pathLib.format(pathLib.join(currentPathObj, entry.name))
				end)
				tableext.extend(queue, childPaths)
			end
		elseif pathLib.extname(currentPath) == ".luau" then
			local rule = loadLintRule(currentPath, VERBOSE)
			if rule then
				registerRule(rule, config, rootLocation, rules, ruleConfigs, ruleIgnores)
			end
		end
	end

	return rules, ruleConfigs, ruleIgnores
end

local function loadDefaultRules(
	config: internalTypes.LintConfig,
	rootLocation: string,
	VERBOSE: boolean
): ({ types.LintRule }, internalTypes.RuleConfigurations, internalTypes.RuleIgnores)
	local rules, ruleConfigs, ruleIgnores = {}, {}, {}
	for _, ruleName in DEFAULT_RULES do
		local path = `./rules/{ruleName}`
		local rule: types.LintRule = require(path) :: any -- Anycast to silence error from dynamic require
		assert(isLintRule(rule, path, VERBOSE), `Invalid default lint rule: {path}`)
		registerRule(rule, config, rootLocation, rules, ruleConfigs, ruleIgnores)
	end
	return rules, ruleConfigs, ruleIgnores
end

local function loadConfig(passedConfigVal: pathLib.Pathlike?, VERBOSE: boolean): internalTypes.LintConfig
	local lintConfig: internalTypes.LintConfig = {}
	local configPath: pathLib.Pathlike = if passedConfigVal
		then passedConfigVal
		else pathLib.join(process.cwd(), ".config.luau")

	if fs.exists(configPath) then
		local success, loadedConfig = pcall(luau.loadModule, configPath, nil)
		if success then
			lintConfig = configUtils.extractConfig(loadedConfig)
		elseif VERBOSE then
			print(`Error loading config:\n{loadedConfig}\nProceeding with defaults.`)
		end
	end
	return lintConfig
end

local function parseDirectives(node: syntax.AstNode): { [string]: boolean }
	local directives: { [string]: boolean } = {}

	local leadingTrivia = triviaUtils.leftmostTrivia(node)
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

	visitor.visitBlock(ast, suppressionVisitor)

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

local function lintString(
	source: string,
	lintRules: { types.LintRule },
	inputFilePath: pathLib.Path?,
	configData: internalTypes.RuleConfigData,
	VERBOSE: boolean
): { types.LintViolation }
	if VERBOSE then
		print(`Parsing input {if inputFilePath then `file '{inputFilePath}'` else "string"}`)
	end
	local ast = syntax.parseBlock(source)

	if VERBOSE then
		print(`Parsing global lint ignores in input {if inputFilePath then `file '{inputFilePath}'` else "string"}`)
	end
	local globalIgnores = parseGlobalIgnores(triviaUtils.leftmostTrivia(ast))

	if VERBOSE then
		print("Applying lint rules")
	end
	local violations: { types.LintViolation } = {}
	local directiveCache = {}
	for _, rule in lintRules do
		if inputFilePath then
			-- check if rule-specific ignores omit the current path
			local ruleIgnores = configData.ruleIgnores[rule.name]
			if ruleIgnores ~= nil and parseIgnores.isIgnored(ruleIgnores, pathLib.format(inputFilePath), false) then
				continue
			end
		end

		local ruleConfig = configData.ruleConfigs[rule.name]
		local context: types.RuleContext = {
			globals = configData.globals,
			options = if ruleConfig.options then ruleConfig.options else {},
		}

		local success, err = pcall(rule.lint, ast, inputFilePath, context)
		local overwrittenSeverity = ruleConfig.severity
		if success then
			-- On success, err contains the returned violations
			for _, violation in err do
				if not violationIsSuppressed(violation, ast, directiveCache, globalIgnores) then
					violation.severity = if overwrittenSeverity then overwrittenSeverity else violation.severity
					table.insert(violations, violation)
				end
			end
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

	return violations
end

type fix = {
	location: syntax.Span,
	replacement: string,
}

local function applySuggestedFixes(source: string, fixes: { fix }): string
	local lines = source:split("\n")

	-- Sort fixes by starting location descending to avoid messing up locations of earlier fixes
	table.sort(fixes, function(a: fix, b: fix)
		return not (a.location < b.location)
	end)

	for _, fix in fixes do
		local beginLine = fix.location.beginLine
		local endLine = fix.location.endLine
		local beginColumn = fix.location.beginColumn
		local endColumn = fix.location.endColumn

		if beginLine == endLine then
			-- Single-line fix
			local line = lines[beginLine]
			lines[beginLine] = line:sub(1, beginColumn - 1) .. fix.replacement .. line:sub(endColumn)
		else
			-- Multi-line fix
			local firstLine = lines[beginLine]
			local lastLine = lines[endLine]

			lines[beginLine] = firstLine:sub(1, beginColumn - 1) .. fix.replacement .. lastLine:sub(endColumn)

			-- Remove the lines that were replaced
			for i = beginLine + 1, endLine do
				lines[i] = nil -- this is cheaper than doing table.remove, but we need to handle the resulting holes later
			end
		end
	end

	local newLines: { string } = {}
	for _, line in lines do -- we rely on the assumption that we'll see the entries in the same order they were created in the array
		table.insert(newLines, line)
	end

	return table.concat(newLines, "\n")
end

local function initialize(passedConfigVal: string?, noDefaults: boolean, rulePath: string?, VERBOSE: boolean)
	if passedConfigVal and fs.type(passedConfigVal) ~= "file" then
		print(`Error: Configuration path must point to a file, not {fs.type(passedConfigVal)}`)
		process.exit(1)
	end

	local configPath: pathLib.Pathlike = if passedConfigVal
		then passedConfigVal
		else pathLib.join(process.cwd(), ".config.luau")

	local lintConfig: internalTypes.LintConfig = loadConfig(passedConfigVal, VERBOSE)

	local lintRules: { types.LintRule } = {}
	local ruleConfigurations: internalTypes.RuleConfigurations = {}
	local ruleIgnoreData: internalTypes.RuleIgnores = {}

	local rootLocation = if fs.exists(configPath)
		then pathLib.format(pathLib.resolve(pathLib.dirname(configPath)))
		else pathLib.format(process.cwd())

	if noDefaults then
		if VERBOSE then
			print("Default lint rules have been disabled.")
		end
	else
		-- add path for each default rule to lintRulePaths
		lintRules, ruleConfigurations, ruleIgnoreData = loadDefaultRules(lintConfig, rootLocation, VERBOSE)
	end

	if rulePath then
		if VERBOSE then
			print(`Loading lint rule(s) from '{rulePath}'`)
		end

		local customRules, customConfigs, customIgnores = loadLintRules(rulePath, lintConfig, rootLocation, VERBOSE)
		tableext.extend(lintRules, customRules)
		tableext.combine(ruleConfigurations, customConfigs)
		tableext.combine(ruleIgnoreData, customIgnores)
	end

	-- load local rules from config rules path
	local configuredRulePaths: { pathLib.Pathlike } = if lintConfig.rulepaths then lintConfig.rulepaths else {}
	for _, path in configuredRulePaths do
		local resolvedPath = pathLib.resolve(rootLocation, path)
		local loadedRules, loadedConfigs, loadedIgnoreData =
			loadLintRules(pathLib.format(resolvedPath), lintConfig, rootLocation, VERBOSE)
		tableext.extend(lintRules, loadedRules)
		tableext.combine(ruleConfigurations, loadedConfigs)
		tableext.combine(ruleIgnoreData, loadedIgnoreData)
	end

	local configContextData = {
		globals = if lintConfig.globals ~= nil then lintConfig.globals else {},
		ruleConfigs = ruleConfigurations,
		ruleIgnores = ruleIgnoreData,
	}

	return {
		lintRules = lintRules,
		configContextData = configContextData :: internalTypes.RuleConfigData,
	}
end

return table.freeze({
	lintString = lintString,
	loadDefaultRules = loadDefaultRules,
	loadLintRules = loadLintRules,
	applySuggestedFixes = applySuggestedFixes,
	loadConfig = loadConfig,
	initialize = initialize,
})
