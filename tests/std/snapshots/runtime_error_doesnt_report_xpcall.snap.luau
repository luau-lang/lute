local test = require("@std/test")

test.suite("nil_field_suite", function(suite)
	suite:case("access_field_of_nil", function(assert)
		local t = nil
		local value = t.field -- This will cause an error
	end)
end)

test.run()
