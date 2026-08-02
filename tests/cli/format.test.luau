local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())
local workdir = path.join(system.tmpdir(), "lute_format_test")

local FORMATTED = "local x = 1\n"
local UNFORMATTED = "  local x = 1\n\n"

local function child(...: string): string
	return path.format(path.join(workdir, ...))
end

test.suite("LuteFormat", function(suite)
	suite:beforeEach(function()
		if fs.exists(workdir) then
			fs.removeDirectory(workdir, { recursive = true })
		end
		fs.createDirectory(workdir, { makeParents = true })
	end)

	suite:afterEach(function()
		if fs.exists(workdir) then
			fs.removeDirectory(workdir, { recursive = true })
		end
	end)

	suite:case("is listed in the top-level help", function(assert)
		local result = process.run({ lutePath, "--help" })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "format          Format specified Luau files. (experimental)")
		assert.strContains(result.stdout, "Format Options:")
	end)

	suite:case("errors when a path holds no Luau files", function(assert)
		fs.writeStringToFile(child("notes.txt"), "not luau\n")

		local result = process.run({ lutePath, "format", path.format(workdir) })
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "no Luau files found")
	end)

	suite:case("discovers Luau files recursively under a directory", function(assert)
		fs.createDirectory(child("nested"))
		fs.writeStringToFile(child("top.luau"), "local x = 1\n")
		fs.writeStringToFile(child("nested", "deep.luau"), "local y = 2\n")
		fs.writeStringToFile(child("ignored.txt"), "not luau\n")

		local result = process.run({ lutePath, "format", "--verbose", path.format(workdir) })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Trying to format {child("top.luau")}`)
		assert.strContains(result.stdout, `Trying to format {child("nested", "deep.luau")}`)
		assert.strNotContains(result.stdout, `Trying to format {child("ignored.txt")}`)
	end)

	suite:case("skips files and directories excluded by .gitignore", function(assert)
		fs.writeStringToFile(child(".gitignore"), "generated.luau\nvendor/\n")
		fs.createDirectory(child("vendor"))
		fs.writeStringToFile(child("src.luau"), "local x = 1\n")
		fs.writeStringToFile(child("generated.luau"), "local y = 2\n")
		fs.writeStringToFile(child("vendor", "dep.luau"), "local z = 3\n")

		local result = process.run({ lutePath, "format", "--verbose", path.format(workdir) })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Trying to format {child("src.luau")}`)
		assert.strNotContains(result.stdout, `Trying to format {child("generated.luau")}`)
		assert.strNotContains(result.stdout, `Trying to format {child("vendor", "dep.luau")}`)
	end)

	suite:case("rewrites a file in place when the formatter changes it", function(assert)
		local target = child("unformatted.luau")
		fs.writeStringToFile(target, UNFORMATTED)

		local result = process.run({ lutePath, "format", "--verbose", target })
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), FORMATTED)
		assert.strContains(result.stdout, `Formatted {target}`)
		assert.strContains(result.stdout, "Formatted 1 of 1 file(s).")
	end)

	suite:case("leaves a file byte-identical when the formatter reports no change", function(assert)
		local target = child("formatted.luau")
		fs.writeStringToFile(target, FORMATTED)

		local result = process.run({ lutePath, "format", "--verbose", target })
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), FORMATTED)
		assert.strNotContains(result.stdout, `Formatted {target}`)
		assert.strContains(result.stdout, "Formatted 0 of 1 file(s).")
	end)

	suite:case("--check reports unformatted files and exits 1 without writing", function(assert)
		local target = child("unformatted.luau")
		fs.writeStringToFile(target, UNFORMATTED)

		local result = process.run({ lutePath, "format", "--check", target })
		assert.eq(result.exitcode, 1)
		assert.eq(fs.readFileToString(target), UNFORMATTED)
		assert.strContains(result.stdout, `1 file(s) not formatted:\n\t- {target}`)
	end)

	suite:case("--check exits 0 when every file is already formatted", function(assert)
		local target = child("formatted.luau")
		fs.writeStringToFile(target, FORMATTED)

		local result = process.run({ lutePath, "format", "--check", "--verbose", target })
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), FORMATTED)
		assert.strContains(result.stdout, "All 1 file(s) were formatted properly.")
	end)

	suite:case("accepts -c and -v as aliases for --check and --verbose", function(assert)
		local target = child("unformatted.luau")
		fs.writeStringToFile(target, UNFORMATTED)

		local long = process.run({ lutePath, "format", "--check", "--verbose", target })
		local short = process.run({ lutePath, "format", "-cv", target })
		assert.eq(long.exitcode, 1)
		assert.eq(short.exitcode, long.exitcode)
		assert.eq(short.stdout, long.stdout)
	end)
end)
