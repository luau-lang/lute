local internalTypes = require("./internaltypes")
local pathLib = require("@std/path")
local types = require("./types")
local lintCore = require("./lintCore")

-- populate in initialize
local lintRules: { types.LintRule } = {}
local configData: internalTypes.GlobalRuleConfigData = {
	ruleConfigs = {},
	ruleIgnores = {},
	globals = {},
	overrides = {},
}

local worker = {}

-- load config, load rules
function worker.initialize(rulesPath: string?, noDefaults: boolean, configPath: string?, verbose: boolean)
	lintRules, configData = lintCore.initialize(configPath, noDefaults, rulesPath, verbose)
end

function worker.lintFile(file: string, autofix: boolean, verbose: boolean): { types.LintViolation }
	return lintCore.lintFile(pathLib.resolve(file), lintRules, autofix, configData, verbose)
end

return table.freeze(worker)
