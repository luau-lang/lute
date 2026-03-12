local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local tmpDir = system.tmpdir()
local tmpOutputDir = path.join(tmpDir, "lute-doc-output")
local lutePath = path.format(process.execpath())

local USAGE = "Usage: lute doc [OPTIONS]"

-- Will add specific module test case (see examples/docs) once --module option is added
test.suite("LuteDoc", function(suite)
	suite:case("luteDocHelpMessage", function(assert)
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

	suite:case("luteDocNoModulesProvided", function(assert)
		local result = process.system(`{lutePath} doc`)

		assert.eq(result.exitcode, 1)
		assert.strcontains(result.stderr, "Error: No module paths specified.")
	end)

	suite:case("luteDocDefaultDirectory", function(assert)
		local result = process.system(`{lutePath} doc definitions lute/std/libs`)

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "Documentation generation complete!")
	end)

	suite:case("luteDocSpecifiedDirectory", function(assert)
		if fs.exists(tmpOutputDir) then
			fs.removedirectory(tmpOutputDir, { recursive = true })
		end

		fs.createdirectory(tmpOutputDir)

		local result = process.system(`{lutePath} doc -o {path.format(tmpOutputDir)} definitions lute/std/libs`)

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "Documentation generation complete!")
		assert.strcontains(result.stdout, tostring(tmpOutputDir)) -- "Files written to: <output dir>"

		assert.eq(fs.exists(path.join(tmpOutputDir, "reference", "lute", "fs.md")), true)
		assert.eq(fs.exists(path.join(tmpOutputDir, "reference", "std", "fs.md")), true)

		fs.removedirectory(tmpOutputDir, { recursive = true })
	end)
end)
