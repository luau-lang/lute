local time = require("@lute/time")

local start = time.now()
for _ = 1, 10000 do
	vector.dot(vector.one, vector.zero)
end
local stop = time.now()

assert(stop > start)
assert(stop ~= start)
assert(start == start)
print((stop - start):tomicroseconds())
