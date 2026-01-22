local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local tmpDir = system.tmpdir()
local tmpOutputDir = path.join(tmpDir, "lute-doc-output")
local lutePath = path.format(process.execpath())

local USAGE = "Usage: lute doc [OPTIONS]"

-- Will add specific module test case (see examples/docs) once --module option is added
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

	suite:case("generate test docs default directory", function(assert)
		local result = process.system(`cd docs && {lutePath} doc`)

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "Documentation generation complete!")
	end)

	suite:case("generate test docs specified directory", function(assert)
		local result = process.system(`cd docs && {lutePath} doc -o {path.format(tmpOutputDir)}`)

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "Documentation generation complete!")
		assert.strcontains(result.stdout, tostring(tmpOutputDir)) -- "Files written to: <output dir>"
	end)
end)
