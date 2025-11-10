local x = math.sqrt(-1)
-- x ~= x should become math.isnan(x)
local b = x ~= x
