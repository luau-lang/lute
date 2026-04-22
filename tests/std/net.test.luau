local net = require("@std/net")
local server = require("@lute/net/server")
local task = require("@lute/task")
local test = require("@std/test")

test.suite("NetTestSuite", function(suite)
	suite:case("serveHandlerCanYield", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(_req: server.ReceivedRequest): server.ServerResponse
				task.wait(0.01)
				task.wait(0.01)
				return {
					status = 200,
					body = "ok",
				}
			end,
		})

		local response = net.request(`{instance.hostname}:{instance.port}`, {
			method = "GET",
		})
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
		assert.eq("ok", response.body)

		instance.close()
	end)

	suite:case("serveLocallyAndRequest", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(_req: server.ReceivedRequest): server.ServerResponse
				return {
					status = 200,
					body = "Hello, World!",
				}
			end,
		})

		local response = net.request(`{instance.hostname}:{instance.port}`, {
			method = "GET",
		})
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
		assert.eq("Hello, World!", response.body)

		instance.close()
	end)
end)
