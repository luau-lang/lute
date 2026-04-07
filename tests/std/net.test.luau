local net = require("@lute/net")
local client = require("@lute/net/client")
local server = require("@lute/net/server")
local test = require("@std/test")

test.suite("NetTestSuite", function(suite)
	suite:case("exposesClientAndServerSubmodules", function(assert)
		assert.eq("function", type(net.request))
		assert.eq("function", type(net.client.request))
		assert.eq("function", type(client.request))
		assert.eq("function", type(net.serve))
		assert.eq("function", type(net.server.serve))
		assert.eq("function", type(server.serve))
	end)

	suite:case("serveLocallyAndRequest", function(assert)
		local server = net.serve({
			handler = function(_req: net.ReceivedRequest): net.ServerResponse
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
