local testtypes = require("@std/test/types")

local function filtertests(
	env: testtypes.TestEnvironment,
	suiteName: string?,
	caseName: string?
): testtypes.TestEnvironment
	local filtered: testtypes.TestEnvironment = {
		anonymous = {},
		suites = {},
		suiteindex = {},
		caseindex = {},
	}

	-- No filters: return all tests
	if not suiteName and not caseName then
		return env
	end

	-- Filter by both suite and case name
	if suiteName and caseName then
		local caseEntry = env.caseindex[caseName]
		if caseEntry and caseEntry.suites[suiteName] then
			local suite = env.suiteindex[suiteName]
			if suite then
				local filteredSuite = table.clone(suite)
				filteredSuite.cases = caseEntry.suites[suiteName]
				table.insert(filtered.suites, filteredSuite)
			end
		end

	-- Filter by suite name only
	elseif suiteName then
		local suite = env.suiteindex[suiteName]
		if suite then
			table.insert(filtered.suites, suite)
		end
	elseif caseName then
		local caseEntry = env.caseindex[caseName]
		if caseEntry then
			-- Add all anonymous tests with this case name
			filtered.anonymous = caseEntry.anonymous

			-- Add all suites that have tests with this case name
			for sName, cases in caseEntry.suites do
				local suite = env.suiteindex[sName]
				if suite then
					local filteredSuite = table.clone(suite)
					filteredSuite.cases = cases
					table.insert(filtered.suites, filteredSuite)
				end
			end
		end
	end

	return filtered
end

return table.freeze({ filtertests = filtertests })
