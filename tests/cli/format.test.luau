local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())
local tmpDir = system.tmpdir()
local USAGE = "Usage: lute format [options] [paths...]"

local function tmpFile(name: string): string
	return path.format(path.join(tmpDir, name))
end

test.suite("lute format", function(suite)
	suite:case("luteFormatHelpMessage", function(assert)
		local result = process.run({ lutePath, "format", "-h" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)
	end)

	suite:case("luteFormatWritesFile", function(assert)
		local filepath = tmpFile("lute_format_writes_file.luau")
		fs.writeStringToFile(filepath, "local x=1")

		local result = process.run({ lutePath, "format", filepath })

		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(filepath), "local x = 1\n")
		fs.remove(filepath)
	end)

	suite:case("luteFormatCheckReportsChanges", function(assert)
		local filepath = tmpFile("lute_format_check_reports_changes.luau")
		fs.writeStringToFile(filepath, "local x=1")

		local result = process.run({ lutePath, "format", "--check", filepath })

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, `Would reformat {filepath}`)
		assert.eq(fs.readFileToString(filepath), "local x=1")
		fs.remove(filepath)
	end)
end)
