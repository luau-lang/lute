-- Helper module that also requires another module
local shared = require("../shared")

-- print("Helper module")
return {
	help = function()
		return "helper"
	end,
	shared = shared,
}
