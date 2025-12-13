local net = require("@std/net")
local test = require("@std/test")
local task = require("@lute/task")

test.suite("NetTestSuite", function(suite)
	suite:case("serve_http_handler_can_yield", function(assert)
		local server = net.serve({
			handler = function(_req: net.receivedrequest): net.serverresponse
				task.wait(0.01)
				return { status = 200, body = "ok" }
			end,
		})

		local response = net.request(`{server.hostname}:{server.port}`, {
			method = "GET",
		})
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
		assert.eq("ok", response.body)

		server.close()
	end)

	suite:case("serve_locally_and_request", function(assert)
		local server = net.serve({
			handler = function(req: net.receivedrequest): net.serverresponse
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

test.run()
