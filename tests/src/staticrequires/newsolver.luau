-- This file should fail the old solver
function add(a, b)
	return a + b
end
local vec2 = {}
function vec2.new(x, y)
	return setmetatable({ x = x or 0, y = y or 0 }, {
		__add = function(v1, v2)
			return { x = v1.x + v2.x, y = v1.y + v2.y }
		end,
	})
end
add(1, 1)
add(vec2.new(0, 0), vec2.new(1, 1))
