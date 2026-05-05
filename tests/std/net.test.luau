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

	suite:case("servesConcurrentClientRequests", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				task.wait(0.01)
				return {
					status = 200,
					body = req.query.id,
				}
			end,
		})

		local done = 0
		local responses = {}

		for i = 1, 3 do
			task.spawn(function()
				local response = net.request(`http://{instance.hostname}:{instance.port}/?id={i}`)
				responses[i] = response.body
				done += 1
			end)
		end

		local start = os.clock()
		while done < 3 and os.clock() - start < 5 do
			task.deferSelf()
		end

		assert.eq(3, done)
		assert.eq("1", responses[1])
		assert.eq("2", responses[2])
		assert.eq("3", responses[3])

		instance.close()
	end)

	suite:case("redirectUsesFinalResponseHeaders", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				if req.path == "/redirect" then
					return {
						status = 302,
						body = "redirecting",
						headers = {
							Location = "/final",
							["X-Stage"] = "redirect",
						},
					}
				end

				return {
					status = 200,
					body = "final",
					headers = {
						["X-Stage"] = "final",
					},
				}
			end,
		})

		local response = net.request(`http://{instance.hostname}:{instance.port}/redirect`)
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
		assert.eq("final", response.body)
		assert.eq("final", response.headers["X-Stage"])

		instance.close()
	end)

	suite:case("customHeadersDisableAutomaticRedirects", function(assert)
		local sawFinal = false
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				if req.path == "/redirect" then
					return {
						status = 302,
						body = "redirecting",
						headers = {
							Location = "/final",
						},
					}
				end

				sawFinal = true
				return {
					status = 200,
					body = req.headers["x-secret"] or "",
				}
			end,
		})

		local response = net.request(`http://{instance.hostname}:{instance.port}/redirect`, {
			headers = {
				["X-Secret"] = "sensitive",
			},
		})
		assert.eq(false, response.ok)
		assert.eq(302, response.status)
		assert.eq("redirecting", response.body)
		assert.eq(false, sawFinal)

		instance.close()
	end)

	suite:case("rejectsInvalidRequestHeaders", function(assert)
		assert.throwsWith("invalid request header name", function()
			net.request("http://example.test", {
				headers = {
					["Bad Header"] = "value",
				},
			})
		end)

		assert.throwsWith("invalid request header value", function()
			net.request("http://example.test", {
				headers = {
					["X-Test"] = "bad\r\nvalue",
				},
			})
		end)
	end)

	suite:case("rejectsGetBody", function(assert)
		assert.throwsWith("GET requests cannot include a body", function()
			net.request("http://example.test", {
				method = "GET",
				body = "not allowed",
			})
		end)
	end)
end)
