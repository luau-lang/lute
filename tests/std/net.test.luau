local net = require("@std/net")
local test = require("@std/test")

test.suite("NetTestSuite", function(suite)
	suite:case("request", function(assert)
		-- Assumption: if this test is running in CI, then the repository's
		-- GitHub page is reachable.
		local response = net.request("https://github.com/luau-lang/lute", {
			method = "GET",
		})
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
	end)
end)

test.run()
