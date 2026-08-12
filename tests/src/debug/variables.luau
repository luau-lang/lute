local a = 12
local _b = 1.2
local _c = "test"
local _d = { 1, 2, 3 }
local _e = { a = 4, b = "5", [4] = { r = 13 } }
local _f = true
local _largeinteger = 123456789101112
local _smallnumber = 12e-15
local _largenumber = 353e104
local _escapechar = "\n\\\r\t\""
local _precise =  1.234567891011

local function g()
	local _k = a + _b
	return _k
end

a += a
g()
