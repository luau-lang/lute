--!strict
local args: { string } = { ... }
assert(#args >= 3)

local shouldPass = args[2] == "pass"

local ok: boolean, result: { string } = pcall(require, args[3])
assert(ok == shouldPass)

if ok then
	assert(type(result) == "table")
	assert(#result == #args - 3)

	for i = 4, #args do
		assert(result[i - 3] == args[i])
	end
else
	assert(type(result) == "string")
	assert(#args == 4)
	assert(result:find(args[4], 1, true) ~= nil)
end
