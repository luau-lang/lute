local func = require("./require_triang")

local sum = 0
for i = 1, 5 do
    sum += func.triangular(3)
end
