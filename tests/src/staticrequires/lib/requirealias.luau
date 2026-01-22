-- Helper module that also requires using an alias
local option = require("@example/option")

-- print("Helper module")
return {
	help = function()
		return "helper"
	end,
	option = option,
}
