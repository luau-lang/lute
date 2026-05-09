local fs = require("@std/fs")
local internalTypes = require("./internaltypes")
local pathLib = require("@std/path")
local tableext = require("@std/tableext")
local types = require("./types")
local lintCore = require("./lintCore")

-- populate in initialize
local lintRules: { types.LintRule } = {}
local configData: internalTypes.RuleConfigData = {
	ruleConfigs = {},
	ruleIgnores = {},
	globals = {},
}

-- load config, load rules
local function initialize(rulePath: string, noDefaults: boolean, passedConfigVal: string, VERBOSE: boolean)
	local lintData = lintCore.initialize(passedConfigVal, noDefaults, rulePath, VERBOSE)
	lintRules, configData = lintData.lintRules, lintData.configContextData
end

local function lintFile(
	inputFilePath: pathLib.Pathlike,
	autofixEnabled: boolean,
	verbose: boolean
): { types.LintViolation }
	if verbose then
		print(`Reading input file '{inputFilePath}'`)
	end
	local fileContent = fs.readFileToString(inputFilePath)

	local violations = lintCore.lintString(fileContent, lintRules, pathLib.resolve(inputFilePath), configData, verbose)

	if not autofixEnabled then
		return violations
	end

	local hasSuggestedFixes = tableext.any(violations, function(violation)
		return violation.suggestedfix ~= nil
	end)

	if not hasSuggestedFixes then
		return violations
	end

	if verbose then
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

	return lintCore.lintString(newContent, lintRules, inputFilePath, configData, verbose)
end

return {
	lintFile = lintFile,
	initialize = initialize,
}
