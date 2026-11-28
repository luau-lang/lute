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

	suite:case("skips files matched by lute.check.ignores", function(assert)
		local fixture = path.format(path.join(process.cwd(), "tests", "src", "typecheck", "check_ignores"))
		local result = process.run({ lutePath, "check", "included.luau", "ignored.d.luau" }, { cwd = fixture })

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "included.luau:")
		assert.strNotContains(result.stdout, "ignored.d.luau:")

		local ignored = process.run({ lutePath, "check", "ignored.d.luau" }, { cwd = fixture })
		assert.eq(ignored.exitcode, 0)
		assert.eq(ignored.stdout, "")
	end)
end)
