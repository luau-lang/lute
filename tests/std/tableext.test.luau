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

	suite:case("fold", function(assert)
		local arr: { number } = { 1, 2, 3, 4 }
		local sum = tableext.fold(arr, function(acc: number, v: number)
			return acc + v
		end, 0)
		assert.eq(sum, 10)
	end)

	suite:case("extend", function(assert)
		local a: { number } = { 1, 2 }
		local b: { number } = { 3, 4 }
		tableext.extend(a, b)
		assert.eq(#a, 4)
		assert.eq(a[3], 3)
		assert.eq(a[4], 4)
	end)
end)

test.run()
