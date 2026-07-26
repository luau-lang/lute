local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())

local function makeDir(name: string): string
	local target = path.format(path.join(system.tmpdir(), name))
	if fs.exists(target) then
		fs.removeDirectory(target, { recursive = true })
	end
	fs.createDirectory(target, { makeParents = true })
	return target
end

local function childPath(dir: string, name: string): string
	return path.format(path.join(path.parse(dir), name))
end

local function writeFile(target: string, contents: string): string
	fs.writeStringToFile(target, contents)
	return target
end

test.suite("LuteFormat", function(suite)
	suite:case("prints help", function(assert)
		local result = process.run({ lutePath, "format", "--help" })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Usage: lute format")
	end)

	suite:case("is listed in the top-level help", function(assert)
		local result = process.run({ lutePath, "--help" })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "format")
		assert.strContains(result.stdout, "Format Options:")
	end)

	suite:case("errors when a path holds no Luau files", function(assert)
		local dir = makeDir("format_empty")
		writeFile(childPath(dir, "notes.txt"), "not luau\n")

		local result = process.run({ lutePath, "format", dir })
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "no Luau files found")

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("discovers Luau files recursively under a directory", function(assert)
		local dir = makeDir("format_walk")
		fs.createDirectory(childPath(dir, "nested"))
		writeFile(childPath(dir, "top.luau"), "local x = 1\n")
		writeFile(childPath(childPath(dir, "nested"), "deep.luau"), "local y = 2\n")
		writeFile(childPath(dir, "ignored.txt"), "not luau\n")

		local result = process.run({ lutePath, "format", "--verbose", dir })
		assert.eq(result.exitcode, 0)
		-- The count proves the walk descended into `nested` and skipped the .txt.
		assert.strContains(result.stdout, "of 2 file(s)")

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("--verbose reports a count in check mode", function(assert)
		local dir = makeDir("format_verbose_check")
		writeFile(childPath(dir, "clean.luau"), "local x = 1\n")

		local result = process.run({ lutePath, "format", "--check", "--verbose", dir })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "All 1 file(s) are formatted.")

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("accepts -v as an alias for --verbose", function(assert)
		local dir = makeDir("format_verbose_alias")
		writeFile(childPath(dir, "clean.luau"), "local x = 1\n")

		local result = process.run({ lutePath, "format", "-v", dir })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "of 1 file(s)")

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("leaves a file byte-identical when the formatter reports no change", function(assert)
		local dir = makeDir("format_noop")
		local source = "local   x=1\nprint(  x  )\n"
		local target = writeFile(childPath(dir, "messy.luau"), source)

		local result = process.run({ lutePath, "format", target })
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), source)

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("--check exits 0 and writes nothing when no file needs formatting", function(assert)
		local dir = makeDir("format_check")
		local source = "local x = 1\n"
		local target = writeFile(childPath(dir, "clean.luau"), source)

		local result = process.run({ lutePath, "format", "--check", target })
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), source)

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("accepts -c as an alias for --check", function(assert)
		local dir = makeDir("format_alias")
		local target = writeFile(childPath(dir, "clean.luau"), "local x = 1\n")

		local result = process.run({ lutePath, "format", "-c", target })
		assert.eq(result.exitcode, 0)

		fs.removeDirectory(dir, { recursive = true })
	end)
end)
