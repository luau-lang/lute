local testtypes = require("@std/test/types")

local function filtertests(
	env: testtypes.testenvironment,
	suiteName: string?,
	caseName: string?
): testtypes.testenvironment
	local filtered: testtypes.testenvironment = {
		anonymous = {},
		suites = {},
		suiteindex = {},
		caseindex = {},
	}

	-- No filters: return all tests
	if not suiteName and not caseName then
		return env
	end

	-- Filter by case name only
	if caseName and not suiteName then
		local caseEntry = env.caseindex[caseName]
		if caseEntry then
			-- Add all anonymous tests with this case name
			filtered.anonymous = caseEntry.anonymous

			-- Add all suites that have tests with this case name
			for sName, cases in caseEntry.suites do
				local suite = env.suiteindex[sName]
				local filteredSuite = {
					name = suite.name,
					cases = cases,
					_beforeeach = suite._beforeeach,
					_beforeall = suite._beforeall,
					_aftereach = suite._aftereach,
					_afterall = suite._afterall,
				}
				table.insert(filtered.suites, filteredSuite)
			end
		end
		return filtered
	end

	-- Filter by suite name only
	if suiteName and not caseName then
		local suite = env.suiteindex[suiteName]
		if suite then
			table.insert(filtered.suites, suite)
		end
		return filtered
	end

	-- Filter by both suite and case name
	if suiteName and caseName then
		local caseEntry = env.caseindex[caseName]
		if caseEntry and caseEntry.suites[suiteName] then
			local suite = env.suiteindex[suiteName]
			local filteredSuite = {
				name = suite.name,
				cases = caseEntry.suites[suiteName],
				_beforeeach = suite._beforeeach,
				_beforeall = suite._beforeall,
				_aftereach = suite._aftereach,
				_afterall = suite._afterall,
			}
			table.insert(filtered.suites, filteredSuite)
		end
		return filtered
	end

	return filtered
end

return table.freeze({ filtertests = filtertests })
