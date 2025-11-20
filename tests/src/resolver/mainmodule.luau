local types = require("@root/types")
local tableext = require("@std/tableext")

local testFilter: { [string]: number } = {
	["a"] = 1,
	["b"] = 2,
}

local a = {}
type tb = { [string]: number }

function a._a(a: number)
	return function(s: string): types.test
		return types(s, a)
	end
end

a._b = tableext.map(testFilter, function(value)
	return tostring(value)
end)

a._metadata = {
	key = -1,
	id = "nice",
}

return a
