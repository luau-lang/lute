local server = require("@lute/net/server")

local instance = server.serve({
	routes = {
		["/"] = "Welcome to lute!",
		["/health"] = { status = 200, body = "ok" },

		["/hello"] = function(_req)
			return { status = 200, body = "hello, world!" }
		end,

		["/users/:id"] = function(req)
			return {
				status = 200,
				headers = { ["Content-Type"] = "text/plain" },
				body = `user id = {req.params.id}`,
			}
		end,

		["/assets/*"] = function(req)
			return { status = 200, body = `asset path = {req.params["*"]}` }
		end,

		["/items/:id"] = {
			GET = function(req)
				return { status = 200, body = `get {req.params.id}` }
			end,
			DELETE = function(req)
				return { status = 204, body = `deleted {req.params.id}` }
			end,
		},
	},

	handler = function(_req)
		return { status = 404, body = "Not Found" }
	end,
})

print(`Server listening on http://{instance.hostname}:{instance.port}`)
