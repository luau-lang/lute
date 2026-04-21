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

	suite:case("routesDispatchExactAndFallback", function(assert)
		local instance = server.serve({
			port = 0,
			routes = {
				["/health"] = "ok",
				["/json"] = {
					status = 200,
					headers = { ["Content-Type"] = "application/json" },
					body = '{"ok":true}',
				},
				["/hello"] = function(_req)
					return { status = 200, body = "hello" }
				end,
			},
			handler = function(_req: server.ReceivedRequest): server.ServerResponse
				return { status = 404, body = "fallback" }
			end,
		})

		local health = net.request(`{instance.hostname}:{instance.port}/health`, { method = "GET" })
		assert.eq(200, health.status)
		assert.eq("ok", health.body)

		local json = net.request(`{instance.hostname}:{instance.port}/json`, { method = "GET" })
		assert.eq(200, json.status)
		assert.eq('{"ok":true}', json.body)
		assert.eq("application/json", json.headers["content-type"] or json.headers["Content-Type"])

		local hello = net.request(`{instance.hostname}:{instance.port}/hello`, { method = "GET" })
		assert.eq(200, hello.status)
		assert.eq("hello", hello.body)

		local fallback = net.request(`{instance.hostname}:{instance.port}/nope`, { method = "GET" })
		assert.eq(404, fallback.status)
		assert.eq("fallback", fallback.body)

		instance.close()
	end)

	suite:case("routesParamAndWildcard", function(assert)
		local instance = server.serve({
			port = 0,
			routes = {
				["/users/me"] = function(_req)
					return { status = 200, body = "me" }
				end,
				["/users/:id"] = function(req)
					return { status = 200, body = `user:{req.params.id}` }
				end,
				["/assets/*"] = function(req)
					return { status = 200, body = `asset:{req.params["*"]}` }
				end,
			},
		})

		local me = net.request(`{instance.hostname}:{instance.port}/users/me`, { method = "GET" })
		assert.eq(200, me.status)
		assert.eq("me", me.body)

		local alice = net.request(`{instance.hostname}:{instance.port}/users/alice`, { method = "GET" })
		assert.eq(200, alice.status)
		assert.eq("user:alice", alice.body)

		local asset = net.request(`{instance.hostname}:{instance.port}/assets/images/logo.png`, { method = "GET" })
		assert.eq(200, asset.status)
		assert.eq("asset:images/logo.png", asset.body)

		local missing = net.request(`{instance.hostname}:{instance.port}/nope`, { method = "GET" })
		assert.eq(404, missing.status)

		instance.close()
	end)

	suite:case("routesMethodDispatch", function(assert)
		local instance = server.serve({
			port = 0,
			routes = {
				["/item/:id"] = {
					GET = function(req)
						return { status = 200, body = `get:{req.params.id}` }
					end,
					POST = function(req)
						return { status = 201, body = `post:{req.params.id}:{req.body}` }
					end,
				},
			},
		})

		local gotten = net.request(`{instance.hostname}:{instance.port}/item/42`, { method = "GET" })
		assert.eq(200, gotten.status)
		assert.eq("get:42", gotten.body)

		local created = net.request(`{instance.hostname}:{instance.port}/item/42`, {
			method = "POST",
			body = "payload",
		})
		assert.eq(201, created.status)
		assert.eq("post:42:payload", created.body)

		local put = net.request(`{instance.hostname}:{instance.port}/item/42`, {
			method = "PUT",
			body = "payload",
		})
		assert.eq(404, put.status)

		instance.close()
	end)
end)
