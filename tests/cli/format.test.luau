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

local function readFile(target: string): string
	local handle = fs.open(target, "r")
	local contents = fs.read(handle)
	fs.close(handle)
	return contents
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

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("discovers Luau files recursively under a directory", function(assert)
		local dir = makeDir("format_walk")
		fs.createDirectory(childPath(dir, "nested"))
		writeFile(childPath(childPath(dir, "nested"), "deep.luau"), "local x = 1\n")

		-- Exits 0 only because the walk reached `deep.luau`; an empty result errors.
		local result = process.run({ lutePath, "format", dir })
		assert.eq(result.exitcode, 0)

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("leaves a file byte-identical when the formatter reports no change", function(assert)
		local dir = makeDir("format_noop")
		local source = "local   x=1\nprint(  x  )\n"
		local target = writeFile(childPath(dir, "messy.luau"), source)

		local result = process.run({ lutePath, "format", target })
		assert.eq(result.exitcode, 0)
		assert.eq(readFile(target), source)

		fs.removeDirectory(dir, { recursive = true })
	end)

	suite:case("--check exits 0 and writes nothing when no file needs formatting", function(assert)
		local dir = makeDir("format_check")
		local source = "local x = 1\n"
		local target = writeFile(childPath(dir, "clean.luau"), source)

		local result = process.run({ lutePath, "format", "--check", target })
		assert.eq(result.exitcode, 0)
		assert.eq(readFile(target), source)

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
