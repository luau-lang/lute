local tableext = require("@std/tableext")

local testFilter: { [string]: number } = {
	["a"] = 1
}

local module = {}

function module.func1(a: number)
	return function(s: string): boolean
        return s == tostring(a)
	end
end

module.strings = tableext.map(testFilter, function(value)
	return tostring(value)
end)

module._metadata = {
	key = -1,
	id = "nice",
}

return module
