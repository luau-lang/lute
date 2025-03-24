local pp = require("@batteries/pp")
local table = require("@std/table")

local baseTable = {
	a = 1,
	b = 2,
	c = 3,
	d = 4,
	e = 5,
}
local secondaryTable = {
	f = 6,
	g = 7,
	h = 8,
	i = 9,
	j = 10,
}

local baseArray = { 1, 2, 3, 4, 5, 5 }
local subArray = { 1, 2, 3 }
local secondaryArray = { 6, 7, 8, 9, 10 }

-- map
local mapped = table.map(baseTable, function(v)
	return v * 2
end)
print("Mapped: ", pp(mapped))

-- filter
local filtered = table.filter(baseTable, function(v)
	return v % 2 == 0
end)
print("Filtered: ", pp(filtered))

-- fold
local folded = table.fold(baseTable, function(acc, v)
	return acc + v
end, 0)
print("Folded: ", folded)

-- union
local unioned = table.union(baseTable, secondaryTable)
print("Unioned: ", pp(unioned))

-- count
local counted = table.count(baseTable)
print("Counted: ", counted)

-- reverse
local reversed = table.reverse(baseArray)
print("Reversed: ", pp(reversed))

-- isArray
local isArray = table.isArray(baseArray)
print("IsArray: ", isArray)

local isNotArray = table.isArray(baseTable)
print("IsNotArray: ", isNotArray)

-- difference
local diffed = table.difference(baseArray, subArray)
print("Difference: ", pp(diffed))

-- contains
local contains = table.contains(baseArray, subArray)
print("Contains: ", contains)

-- find
local found = table.find(baseTable, 3)
print("Found: ", found)

-- union
local unioned = table.union(baseTable, secondaryTable)
print("Unioned: ", pp(unioned))

-- set
local setted = table.set(baseArray)
print("Setted: ", pp(setted))
