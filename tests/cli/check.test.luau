local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local lutePath = path.format(process.execPath())

test.suite("LuteTypeCheck", function(suite)
	suite:case("usesNewSolver", function(assert)
		local testFilePath = path.format(path.join("tests", "src", "staticrequires", "newsolver.luau"))

		local result = process.run({ lutePath, "check", testFilePath })
		assert.eq(result.exitcode, 0)
	end)

	suite:case("appliesLuteFflags", function(assert)
		local testFilePath = path.format(path.join("tests", "src", "staticrequires", "fflags.luau"))

		local result = process.run({ lutePath, "check", testFilePath })
		assert.eq(result.exitcode, 0)

		local env = table.clone(process.env)
		env.LUTE_FFLAGS = "LuauSolverConstraintLimit=1"

		result = process.run({ lutePath, "check", testFilePath }, { env = env })
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "Code is too complex to typecheck")
	end)
end)
