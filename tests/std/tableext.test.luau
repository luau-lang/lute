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

	suite:case("reverse", function(assert)
		-- in-place
		local a = { 1, 2, 3 }
		tableext.reverse(a, true)
		assert.tableeq(a, { 3, 2, 1 })

		-- return new
		local b = { 4, 5, 6 }
		local c = tableext.reverse(b)
		assert.tableeq(b, { 4, 5, 6 })
		assert.tableeq(c, { 6, 5, 4 })
	end)

	suite:case("toset", function(assert)
		local a = { 1, 2, 4, 2, 1 }
		local setA = tableext.toset(a)
		assert.eq(setA[1], true)
		assert.eq(setA[2], true)
		assert.eq(setA[3], nil)
		assert.eq(setA[4], true)
		assert.eq(setA[5], nil)

		local setSize = #tableext.keys(setA)
		assert.eq(setSize, 3)
		assert.neq(setSize, #a)

		-- Sanity check: sets created using an array of numbers don't break from having "gaps" between the number keys.

		local foundKeys: { number } = {}
		for key, value in setA do
			assert.eq(value, true)
			table.insert(foundKeys, key)
		end
		assert.eq(#foundKeys, setSize)
		assert.eq(setA[foundKeys[1]], true)
		assert.eq(setA[foundKeys[2]], true)
		assert.eq(setA[foundKeys[3]], true)

		local b = { "a", "b", "c", "a" }
		local setB = tableext.toset(b)
		assert.eq(setB["a"], true)
		assert.eq(setB["b"], true)
		assert.eq(setB["c"], true)
		assert.eq(setB["d"], nil)
		assert.eq(#tableext.keys(setB), 3)
		assert.neq(#tableext.keys(setB), #b)
	end)

	suite:case("any", function(assert)
		local a = { 1, 2, 3, 4, 5 }
		local hasEven = tableext.any(a, function(v: number)
			return v % 2 == 0
		end)
		assert.eq(hasEven, true)

		local hasGreaterThanFive = tableext.any(a, function(v: number)
			return v > 5
		end)
		assert.eq(hasGreaterThanFive, false)
	end)

	suite:case("all", function(assert)
		local a = { 2, 4, 6, 8 }
		local allEven = tableext.all(a, function(v: number)
			return v % 2 == 0
		end)
		assert.eq(allEven, true)

		local allLessThanEight = tableext.all(a, function(v: number)
			return v < 8
		end)
		assert.eq(allLessThanEight, false)
	end)
end)
