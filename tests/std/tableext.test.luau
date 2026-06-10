local tableext = require("@std/tableext")
local test = require("@std/test")

test.suite("TableExt", function(suite)
	suite:case("mapAndFilter", function(assert)
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
		assert.eq(a, { 3, 2, 1 })

		-- return new
		local b = { 4, 5, 6 }
		local c = tableext.reverse(b)
		assert.eq(b, { 4, 5, 6 })
		assert.eq(c, { 6, 5, 4 })
	end)

	suite:case("toSet", function(assert)
		local a = { 1, 2, 4, 2, 1 }
		local setA = tableext.toSet(a)
		assert.that(setA[1])
		assert.that(setA[2])
		assert.eq(setA[3], nil)
		assert.that(setA[4])
		assert.eq(setA[5], nil)

		local setSize = #tableext.keys(setA)
		assert.eq(setSize, 3)
		assert.neq(setSize, #a)

		-- Sanity check: sets created using an array of numbers don't break from having "gaps" between the number keys.

		local foundKeys: { number } = {}
		for key, value in setA do
			assert.that(value)
			table.insert(foundKeys, key)
		end
		assert.eq(#foundKeys, setSize)
		assert.that(setA[foundKeys[1]])
		assert.that(setA[foundKeys[2]])
		assert.that(setA[foundKeys[3]])

		local b = { "a", "b", "c", "a" }
		local setB = tableext.toSet(b)
		assert.that(setB["a"])
		assert.that(setB["b"])
		assert.that(setB["c"])
		assert.eq(setB["d"], nil)
		assert.eq(#tableext.keys(setB), 3)
		assert.neq(#tableext.keys(setB), #b)

		local empty = {}
		local emptySet = tableext.toSet(empty)
		assert.eq(#emptySet, 0)
	end)

	suite:case("any", function(assert)
		local a = { 1, 2, 3, 4, 5 }
		local hasEven = tableext.any(a, function(v: number)
			return v % 2 == 0
		end)
		assert.that(hasEven)

		local hasGreaterThanFive = tableext.any(a, function(v: number)
			return v > 5
		end)
		assert.eq(hasGreaterThanFive, false)

		a = {}
		local anyInEmpty = tableext.any(a, function(_: number)
			return true
		end)
		assert.eq(anyInEmpty, false)
	end)

	suite:case("all", function(assert)
		local a = { 2, 4, 6, 8 }
		local allEven = tableext.all(a, function(v: number)
			return v % 2 == 0
		end)
		assert.that(allEven)

		local allLessThanEight = tableext.all(a, function(v: number)
			return v < 8
		end)
		assert.eq(allLessThanEight, false)

		a = {}
		local allInEmpty = tableext.all(a, function(_: number)
			return false
		end)
		assert.that(allInEmpty)
	end)

	suite:case("mappedConcat", function(assert)
		local nums = { 1, 2, 3 }
		local result = tableext.mappedConcat(nums, function(v: number)
			return tostring(v)
		end)
		assert.eq(result, "123")

		local withSep = tableext.mappedConcat(nums, function(v: number)
			return tostring(v)
		end, ", ")
		assert.eq(withSep, "1, 2, 3")

		local words = { "hello", "world" }
		local joined = tableext.mappedConcat(words, function(v: string)
			return v
		end, " ")
		assert.eq(joined, "hello world")

		local empty: { number } = {}
		local emptyResult = tableext.mappedConcat(empty, function(v: number)
			return tostring(v)
		end, ",")
		assert.eq(emptyResult, "")

		local single = { 42 }
		local singleResult = tableext.mappedConcat(single, function(v: number)
			return tostring(v)
		end, ",")
		assert.eq(singleResult, "42")
	end)

	suite:case("deepclone", function(assert)
		-- Empty table
		local empty = {}
		local emptyClone = tableext.deepClone(empty)
		assert.eq(#emptyClone, 0)
		assert.that(emptyClone ~= empty)

		-- Flat table: clone has same values
		local flat = { a = 1, b = 2, c = 3 }
		local flatClone = tableext.deepClone(flat)
		assert.eq(flatClone.a, 1)
		assert.eq(flatClone.b, 2)
		assert.eq(flatClone.c, 3)
		assert.that(flatClone ~= flat)

		-- Flat table: mutating clone does not affect original
		flatClone.a = 99
		assert.eq(flat.a, 1)

		-- Array-like table
		local arr = { 10, 20, 30 }
		local arrClone = tableext.deepClone(arr)
		assert.eq(arrClone[1], 10)
		assert.eq(arrClone[2], 20)
		assert.eq(arrClone[3], 30)
		assert.that(arrClone ~= arr)

		-- Nested table: clone is deep (independent nested tables)
		local nested = { x = { y = { z = 42 } } }
		local nestedClone = tableext.deepClone(nested)
		assert.eq(nestedClone.x.y.z, 42)
		assert.that(nestedClone.x ~= nested.x)
		assert.that(nestedClone.x.y ~= nested.x.y)

		-- Nested table: mutating a nested clone does not affect original
		nestedClone.x.y.z = 0
		assert.eq(nested.x.y.z, 42)

		-- Mixed table: nested arrays and dicts
		local mixed = { nums = { 1, 2, 3 }, meta = { count = 3 } }
		local mixedClone = tableext.deepClone(mixed)
		assert.eq(mixedClone.nums[1], 1)
		assert.eq(mixedClone.meta.count, 3)
		assert.that(mixedClone.nums ~= mixed.nums)
		assert.that(mixedClone.meta ~= mixed.meta)

		mixedClone.nums[1] = 99
		mixedClone.meta.count = 99
		assert.eq(mixed.nums[1], 1)
		assert.eq(mixed.meta.count, 3)
	end)
end)
