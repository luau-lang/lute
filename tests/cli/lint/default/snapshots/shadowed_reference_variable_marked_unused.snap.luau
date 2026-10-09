local function fresh()
	return { a = 1 }
end

local x = (fresh())
x.a += 1

-- This is not used
local x = fresh()

-- Unused here
local y = fresh()

local y = fresh()
y.a += 1
