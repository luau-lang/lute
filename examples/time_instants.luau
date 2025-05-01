local time = require("@lute/time")

local start = time.now()
for i = 1, 10000 do
	vector.dot(vector.one, vector.zero)
end
local stop = time.now()

print((stop - start):tomicroseconds())
