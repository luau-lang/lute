local net = require("@std/net")
local server = require("@lute/net/server")
local test = require("@std/test")

test.suite("NetTestSuite", function(suite)

	suite:case("serveLocallyAndRequest", function(assert)
		local server = server.serve({
			handler = function(_req: server.ReceivedRequest): server.ServerResponse
				return {
					status = 200,
					body = "Hello, World!",
				}
			end,
		})

		local response = net.request(`{server.hostname}:{server.port}`, {
			method = "GET",
		})
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
		assert.eq("Hello, World!", response.body)

		server.close()
	end)
end)
