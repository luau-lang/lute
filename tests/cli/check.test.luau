local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execpath())

test.suite("LuteTypeCheck", function(suite)
	suite:case("UsesNewSolver", function(assert)
		local testFilePath = path.format(path.join("tests", "src", "staticrequires", "newsolver.luau"))

		local result = process.run({ lutePath, "check", testFilePath })
		assert.eq(result.exitcode, 0)
		fs.remove(testFilePath)
	end)
end)
