local a = 12
local _b = 1.2
local _c = "test"
local _d = {1, 2, 3}
local _e = {a = 4, b = "5", [4] = {r=13}}
local _f = true

local function g()
    local _k = a + _b
    return _k
end

a += a
g()
