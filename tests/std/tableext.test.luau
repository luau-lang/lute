local tableext = require("@std/tableext")
local test = require("@std/test")

test.suite("TableExt", function(suite)
	suite:case("map_and_filter", function(assert)
		local t: { [string]: number } = { a = 1, b = 2, c = 3 }
		local mapped = tableext.map(t, function(v: number)
			return v * 2
		end)
		assert.eq(mapped.a, 2)
		assert.eq(mapped.b, 4)
		assert.eq(mapped.c, 6)

		local filtered = tableext.filter(t, function(v: number)
			return v % 2 == 1
		end)
		assert.eq(filtered.a, 1)
		assert.eq(filtered.b, nil)
		assert.eq(filtered.c, 3)
	end)

	suite:case("extend", function(assert)
		local a: { number } = { 1, 2 }
		local b: { number } = { 3, 4 }
		local c: { number } = { 5, 6 }
		tableext.extend(a, b, c)
		assert.eq(#a, 6)
		assert.eq(a[3], 3)
		assert.eq(a[4], 4)
		assert.eq(a[5], 5)
		assert.eq(a[6], 6)
	end)

	suite:case("combine", function(assert)
		local a = { ["a"] = 1, ["b"] = 2 }
		local b = { ["b"] = 3, ["c"] = 4 }
		local c = { ["c"] = 1, ["d"] = 5 }
		tableext.combine(a, b, c)
		assert.eq(a["a"], 1)
		assert.eq(a["b"], 3)
		assert.eq(a["c"], 1)
		assert.eq(a["d"], 5)
	end)

	suite:case("keys", function(assert)
		local a = { a = 1, b = 2, c = 3 }
		local keys = tableext.keys(a)
		for _, key in keys do
			assert.neq(a[key], nil)
		end
	end)
end)

test.run()
