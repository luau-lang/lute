local time = require("@lute/time")

local start = time.now()
for i = 1, 100000 do
	local _ = i * 2
end
print(time.now() - start)
