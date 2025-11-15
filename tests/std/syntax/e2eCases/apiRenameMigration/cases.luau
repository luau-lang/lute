local types = require("../types")
type Case = types.Case

return {
	-- Test 1: Simple function rename
	{
		initial = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local result = sameLibrary.numFunc(1)
]],
		expected = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local result = sameLibrary.processNumber(1)
]],
	},
	-- Test 2: Function rename with type change (number -> string)
	{
		initial = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local result = sameLibrary.arrayFunc({1, 2, 3})
]],
		expected = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local result = sameLibrary.processArray(1, 2, 3)
]],
	},
	-- Test 3: Multiple function calls with renames and type changes
	{
		initial = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local a = sameLibrary.numFunc(42)
local b = sameLibrary.arrayFunc({10, 20, 30})
local c = sameLibrary.stringFunc("hello")
]],
		expected = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local a = sameLibrary.processNumber(42)
local b = sameLibrary.processArray(10, 20, 30)
local c = sameLibrary.handleText("hello")
]],
	},
	-- Test 4: Nested function calls
	{
		initial = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local result = sameLibrary.numFunc(sameLibrary.getCount())
]],
		expected = [[
local sameLibrary = require(packagesRoot.sameLibrary)

local result = sameLibrary.processNumber(sameLibrary.retrieveCount())
]],
	},
	-- 	-- Test 5: Function calls with table arguments that need type conversion
	-- 	{
	-- 		initial = [[
	-- local sameLibrary = require(packagesRoot.sameLibrary)

	-- local data = {x = 1, y = 2}
	-- local result = sameLibrary.processData(data)
	-- ]],
	-- 		expected = [[
	-- local sameLibrary = require(packagesRoot.sameLibrary)

	-- local data = {x = "1", y = "2"}
	-- local result = sameLibrary.handleData(data)
	-- ]],
	-- },
} :: { Case }
