local a = require("./a")
local _types = require(
	"./types_example"
)
local _comments = 
	require(
		"./comments_example"
	)
if false then
	local _ignore_this = require("../ignore_this")
end

type example = _types.ReactProvider<number>

local function stuff(arg: a.TypeA): number
	local result: number = arg.a + 1
	return result :: number
end


do
	-- This will produce a LocalShadow warning in the bundled output if b's globalFunction is incorrectly scoped
	local globalFunction = nil
end
-- This will throw an error if this env has access to b's globalFunction
if type(globalFunction) ~= "nil" then
	error("Should not access globalFunction in this environment!")
end

function emptyFunction() end

print("Hello, World!", a.a, stuff(a))
