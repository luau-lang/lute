local internalTypes = require("./internaltypes")

local function assertIsArray(arr: { any }, type: string, err: string)
	for k, v in arr do
		assert(typeof(k) == "number", err)
		assert(typeof(v) == type, err)
	end
end

-- we expect .config.luau file structured s.t top level table has: table.lute.lint field
local function assertValidConfig(candidate: any)
	if candidate.ignores then
		assert(typeof(candidate.ignores) == "table", "config.lute.lint.ignores must be an array of filepath globs")
		assertIsArray(candidate.ignores, "string", "config.lute.lint.ignores must be an array of filepath globs")
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
