local function f(x: int)
	local tot = 0
	for i = 1, 10 do
		tot += x * i
	end
	return tot
end

local a = 0
local ret = f(5)
local ret2 = f(9)
a += ret + ret2
