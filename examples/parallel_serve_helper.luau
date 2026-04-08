local server = require("@lute/net/server")

return {
	serve = function()
		server.serve({
			handler = function(_)
				return "Hello, lute!"
			end,
			reuseport = true,
		})
	end,
}
