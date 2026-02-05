local types = require("./types")

-- we expect .config.luau file structured s.t top level table has: table.lute.lint field
local function assertValidConfig(candidate: any)
	if candidate.ignores then
		assert(typeof(candidate.ignores) == "table", "config.ignores must be a table of strings.")
	end
	if candidate.globals then
		assert(typeof(candidate.globals) == "table", "config.globals must be a table of [string] : unknown")
	end
	if candidate.rules then
		if candidate.rules.paths then
			assert(typeof(candidate.ignores) == "table", "config.ignores must be a table of strings.")
		end
	end
end

local function extractConfig(candidate: any): types.LintConfig
	local luteLintConfig = candidate.lute and candidate.lute.lint
	if luteLintConfig then
		assertValidConfig(luteLintConfig)
		return luteLintConfig
	end

	return {}
end

return {
	extractConfig = extractConfig,
}
