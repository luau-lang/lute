local t = {}
setmetatable(t, {
	__index = function(_, k)
		return k
	end,
	__call = function(_, k)
		return k
	end,
})

t(5)
local _z = t[7]
