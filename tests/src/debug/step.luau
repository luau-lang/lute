local function f(x: int)
	local tot = 0
	for i = 1, 10 do
		tot += x * i
	end
	return tot
end

local _a = 0
local ret = f(5)
local ret2 = f(9)
_a += ret + ret2
