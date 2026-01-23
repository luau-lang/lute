-- Helper module that also requires using an alias
local example = require("@nested/example")

-- print("Helper module")
return {
	help = function()
		return "helper"
	end,
	example = example,
}
