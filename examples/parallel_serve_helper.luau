local net = require("@lute/net")

return {
	serve = function()
		net.serve({
			handler = function(_)
				return "Hello, lute!"
			end,
			reuseport = true,
		})
	end,
}
