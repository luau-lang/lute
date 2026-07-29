local func = require("./require_triang")

local _sum = 0
for _ = 1, 5 do
	_sum += func.triangular(3)
end
