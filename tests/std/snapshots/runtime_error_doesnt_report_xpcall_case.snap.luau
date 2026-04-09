local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("access_field_of_nil", function(assert)
	local t = nil :: any
	local value = t.field -- This will cause an error
	print(value)
end)

runner.runRegisteredTests()
