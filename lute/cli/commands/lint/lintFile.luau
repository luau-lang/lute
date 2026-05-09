local fs = require("@std/fs")
local internalTypes = require("./internaltypes")
local pathLib = require("@std/path")
local tableext = require("@std/tableext")
local types = require("./types")
local lintCore = require("./lintCore")

type InitializeArgs = {
	rulePath: string?,
	noDefaults: boolean,
	configPath: string?,
	verbose: boolean,
}

type LintFileArgs = {
	file: string,
	autofix: boolean,
	verbose: boolean,
}

-- populate in initialize
local lintRules: { types.LintRule } = {}
local configData: internalTypes.RuleConfigData = {
	ruleConfigs = {},
	ruleIgnores = {},
	globals = {},
}

-- load config, load rules
local function initialize(args: InitializeArgs)
	local lintData = lintCore.initialize(args.configPath, args.noDefaults, args.rulePath, args.verbose)
	lintRules, configData = lintData.lintRules, lintData.configContextData
end

local function lintFile(args: LintFileArgs): { types.LintViolation }
	local inputFilePath = args.file
	local resolvedInputFilePath = pathLib.resolve(inputFilePath)

	if args.verbose then
		print(`Reading input file '{inputFilePath}'`)
	end
	local fileContent = fs.readFileToString(inputFilePath)

	local violations = lintCore.lintString(fileContent, lintRules, resolvedInputFilePath, configData, args.verbose)

	if not args.autofix then
		return violations
	end

	local hasSuggestedFixes = tableext.any(violations, function(violation)
		return violation.suggestedfix ~= nil
	end)

	if not hasSuggestedFixes then
		return violations
	end

	if args.verbose then
		print(`Applying suggested fixes to file '{inputFilePath}'`)
	end

	local fixes: { types.fix } = {}
	for _, violation in violations do
		if violation.suggestedfix ~= nil then
			local fixLocation = violation.suggestedfix.location or violation.location
			table.insert(fixes, { location = fixLocation, replacement = violation.suggestedfix.fix })
		end
	end

	local newContent = lintCore.applySuggestedFixes(fileContent, fixes)

	fs.writeStringToFile(inputFilePath, newContent)

	return lintCore.lintString(newContent, lintRules, resolvedInputFilePath, configData, args.verbose)
end

return {
	lintFile = lintFile,
	initialize = initialize,
}
