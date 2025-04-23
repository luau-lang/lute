local net = require("@lute/net")

return {
	serve = function()
		net.serve(function(req)
			return "Hello, lute!"
		end)
	end,
}
