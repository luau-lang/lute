local internalTypes = require("./internaltypes")
local pathLib = require("@std/path")
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

local worker = {}

-- load config, load rules
function worker.initialize(args: InitializeArgs)
	lintRules, configData = lintCore.initialize(args.configPath, args.noDefaults, args.rulePath, args.verbose)
end

function worker.lintFile(args: LintFileArgs): { types.LintViolation }
	return lintCore.lintFile(pathLib.resolve(args.file), lintRules, args.autofix, configData, args.verbose)
end

return table.freeze(worker)
