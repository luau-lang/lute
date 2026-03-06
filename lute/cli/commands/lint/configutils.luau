local internalTypes = require("./internaltypes")

local function assertTableStructure(arr: { [any]: any }, keytype: string, valuetype: string?, err: string)
	for k, v in arr do
		assert(typeof(k) == keytype, err)
		if valuetype then
			assert(typeof(v) == valuetype, err)
		end
	end
end

local function assertIsArray(arr: { any }, valuetype: string, err: string)
	return assertTableStructure(arr, "number", valuetype, err)
end

-- we expect .config.luau file structured s.t top level table has: table.lute.lint field
local function assertValidConfig(candidate: any)
	if candidate.ignores then
		assert(typeof(candidate.ignores) == "table", "config.lute.lint.ignores must be an array of filepath globs")
		assertIsArray(candidate.ignores, "string", "config.lute.lint.ignores must be an array of filepath globs")
	end

	if candidate.globals then
		assert(typeof(candidate.globals) == "table", "config.lute.lint must be a table with string keys")
		assertTableStructure(candidate.globals, "string", nil, "config.lute.lint must be a table with string keys")
	end

	if candidate.rulepaths then
		assert(typeof(candidate.rulepaths) == "table", "config.lute.lint.rulepaths must be an array of filepath globs")
		assertIsArray(candidate.rulepaths, "string", "config.lute.lint.rulepaths must be an array of filepath globs")
	end

	if candidate.ruleconfigs then
		assert(typeof(candidate.ruleconfigs) == "table", "config.lute.lint must be a table with string keys")
		assertTableStructure(candidate.ruleconfigs, "string", nil, "config.lute.lint must be a table with string keys")
	end
end

local function extractConfig(candidate: any): internalTypes.LintConfig
	local luteLintConfig = if candidate.lute ~= nil then candidate.lute.lint else nil -- LUAUFIX: I would expect candidate : any to silence this error
	if luteLintConfig then
		assertValidConfig(luteLintConfig)
		return luteLintConfig
	end

	return {}
end

return {
	extractConfig = extractConfig,
}
