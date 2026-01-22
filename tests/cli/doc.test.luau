local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local lutePath = path.format(process.execpath())

local USAGE = "Usage: lute doc [OPTIONS]"

-- Will add `lute doc` execution with specific module test case (see examples/docs) once --module option is added
-- Currently, `lute doc` writes to hard-coded output directories that `process.run` does not have write access to.
test.suite("lute-doc", function(suite)
	suite:case("lute doc help message", function(assert)
		local result = process.run({ lutePath, "doc", "-h" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, USAGE)

		result = process.run({ lutePath, "doc", "--h" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, USAGE)

		result = process.run({ lutePath, "doc", "--help" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, USAGE)
	end)
end)
