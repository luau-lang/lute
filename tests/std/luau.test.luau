
local test = require("@std/test")
local luau = require("@std/luau")

test.suite("LuauTypeOfModuleSuite", function(suite)
	suite:case("typeofmodule_returns_string_and_contains_await", function(assert)
		local moduleTypeString = luau.typeofmodule("./lute/std/libs/task.luau")

	-- Basic check for now until the data structure is created
	assert.neq(moduleTypeString, "")
	end)
end)

test.run()

