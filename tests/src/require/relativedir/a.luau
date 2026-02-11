--!strict

export type TypeA = {
	a: number,
}

local a = 1
local b = require("./b")

-- This is a comment

local function _printInterpolatedString()
	local str = "Hello"
	local var = 123
	print(
		str,
		`World!: {var}`
	)
end

return { a = a + b } :: TypeA
