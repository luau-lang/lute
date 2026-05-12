local net = require("@std/net")
local server = require("@lute/net/server")
local task = require("@lute/task")
local test = require("@std/test")
local time = require("@std/time")

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

	suite:case("runsMoreThanFourClientRequestsConcurrently", function(assert)
		local requestCount = 5
		local responseDelay = 0.2
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				task.wait(responseDelay)
				return {
					status = 200,
					body = req.query.id,
				}
			end,
		})

		local done = 0
		local start = time.now()

		for i = 1, requestCount do
			task.spawn(function()
				net.request(`http://{instance.hostname}:{instance.port}/?id={i}`)
				done += 1
			end)
		end

		while done < requestCount and time.since(start) < 5 do
			task.wait()
		end

		local elapsed = time.since(start)

		assert.eq(requestCount, done)
		assert.that(
			elapsed < responseDelay * 1.25,
			`expected {requestCount} delayed requests to complete concurrently, took {elapsed}s`
		)

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

	suite:case("rejectsInvalidRequestHeaders", function(assert)
		assert.throwsWith("invalid request header name", function()
			net.request("http://example.test", {
				headers = {
					["Bad Header"] = "value",
				},
			})
		end)

		assert.throwsWith("invalid request header name", function()
			net.request("http://example.test", {
				headers = {
					["Bad\0Header"] = "value",
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

		assert.throwsWith("invalid request header value", function()
			net.request("http://example.test", {
				headers = {
					["X-Test"] = "bad\0value",
				},
			})
		end)

		assert.throwsWith("invalid request header value", function()
			net.request("http://example.test", {
				headers = {
					["X-Test"] = "bad\1value",
				},
			})
		end)

		assert.throwsWith("invalid request header value", function()
			net.request("http://example.test", {
				headers = {
					["X-Test"] = "bad\128value",
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

	suite:case("rejectsHeadBody", function(assert)
		assert.throwsWith("HEAD requests cannot include a body", function()
			net.request("http://example.test", {
				method = "HEAD",
				body = "not allowed",
			})
		end)
	end)

	suite:case("twoRequestsCompleteWithoutCrashing", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(_req: server.ReceivedRequest): server.ServerResponse
				task.wait(0.05)
				return { status = 200, body = "ok" }
			end,
		})

		local done = 0

		for _ = 1, 2 do
			task.spawn(function()
				net.request(`http://{instance.hostname}:{instance.port}/`)
				done += 1
			end)
		end

		local start = time.now()

		while done < 2 and time.since(start) < 5 do
			task.wait()
		end

		assert.eq(2, done)
		instance.close()
	end)

	suite:case("postRequestSendsBody", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				return { status = 200, body = req.body }
			end,
		})

		local response = net.request(`http://{instance.hostname}:{instance.port}/`, {
			method = "POST",
			body = "hello world",
		})

		assert.eq(true, response.ok)
		assert.eq("hello world", response.body)
		instance.close()
	end)

	suite:case("requestHeadersAreForwarded", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest): server.ServerResponse
				return { status = 200, body = req.headers["x-custom"] or "" }
			end,
		})

		local response = net.request(`http://{instance.hostname}:{instance.port}/`, {
			headers = { ["X-Custom"] = "sentvalue" },
		})

		assert.eq("sentvalue", response.body)
		instance.close()
	end)

	suite:case("requestToClosedPortFails", function(assert)
		local failed = false
		local done = false

		task.spawn(function()
			local ok = pcall(net.request, "http://127.0.0.1:0/")
			failed = not ok
			done = true
		end)

		local start = time.now()

		while not done and time.since(start) < 5 do
			task.wait()
		end

		assert.eq(true, done)
		assert.eq(true, failed)
	end)
end)
