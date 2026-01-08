local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execpath())
local tmpDir = system.tmpdir()

test.suite("LuteTypeCheck", function(suite)
	suite:case("UsesNewSolver", function(assert)
		local testFilePath = path.format(path.join(tmpDir, "check_new_solver.luau"))
		-- This file should fail the old solver
		fs.writestringtofile(
			testFilePath,
			[[
function add(a, b)
	return a + b
end
local vec2 = {}
function vec2.new(x, y)
	return setmetatable({ x = x or 0, y = y or 0 }, {
		__add = function(v1, v2)
			return { x = v1.x + v2.x, y = v1.y + v2.y }
		end,
	})
end
add(1, 1)
add(vec2.new(0, 0), vec2.new(1, 1))

add(vec2.new(0, 0), vec2.new(1,1))
]]
		)

		local result = process.run({ lutePath, "check", testFilePath })
		assert.eq(result.exitcode, 0)
		fs.remove(testFilePath)
	end)
end)
