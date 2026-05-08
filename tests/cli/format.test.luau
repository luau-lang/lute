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

	suite:case("luteFormatCheckReportsMultipleFilesInOrder", function(assert)
		local firstPath = tmpFile("lute_format_check_reports_multiple_files_first.luau")
		local secondPath = tmpFile("lute_format_check_reports_multiple_files_second.luau")
		fs.writeStringToFile(firstPath, "local first=1")
		fs.writeStringToFile(secondPath, "local second=2")

		local result = process.run({ lutePath, "format", "--check", firstPath, secondPath })

		assert.eq(result.exitcode, 1)
		local firstOutput = `Would reformat {firstPath}`
		local secondOutput = `Would reformat {secondPath}`
		local firstIndex = result.stdout:find(firstOutput, 1, true)
		local secondIndex = result.stdout:find(secondOutput, 1, true)
		assert.eq(firstIndex ~= nil, true)
		assert.eq(secondIndex ~= nil, true)
		if firstIndex ~= nil and secondIndex ~= nil then
			assert.eq(firstIndex < secondIndex, true)
		end
		assert.eq(fs.readFileToString(firstPath), "local first=1")
		assert.eq(fs.readFileToString(secondPath), "local second=2")
		fs.remove(firstPath)
		fs.remove(secondPath)
	end)
end)
