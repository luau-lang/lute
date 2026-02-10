local x = math.sqrt(-1)
-- x ~= x should become math.isnan(x)
local _b = x ~= x
