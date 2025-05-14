local net = require("@lute/net")

return {
	serve = function()
		net.serve({
			handler = function(req)
				return "Hello, lute!"
			end,
			reuseport = true,
		})
	end,
}
