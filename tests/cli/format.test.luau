local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local testutil = require("../testutil")

local lutePath = path.format(process.execPath())
local workdir = path.join(system.tmpdir(), "lute_format_test")
local fixtures = path.join(process.cwd(), "tests", "cli", "format", "fixtures")

local function fixture(...: string): path.Path
	return path.join(fixtures, ...)
end

local function readNormalizedFile(file: path.Pathlike): string
	return testutil.normalizeLineEndings(fs.readFileToString(file))
end

local function child(...: string): string
	return path.format(path.join(workdir, ...))
end

local function copyDirectory(source: path.Path, destination: path.Path)
	for _, entry in fs.listDirectory(source) do
		local from = path.join(source, entry.name)
		local to = path.join(destination, entry.name)

		if entry.type == "dir" then
			fs.createDirectory(to)
			copyDirectory(from, to)
		else
			fs.writeStringToFile(to, readNormalizedFile(from))
		end
	end
end

local function copyFixture(name: string)
	copyDirectory(fixture(name), workdir)
end

local FORMATTED = readNormalizedFile(fixture("formatting", "formatted.luau"))
local UNFORMATTED = readNormalizedFile(fixture("formatting", "unformatted.luau"))

local function runLuteFrom(cwd: string, ...: string): process.ProcessResult
	local result = process.run({ lutePath, ... }, { cwd = cwd })
	result.stdout = testutil.normalizeLineEndings(result.stdout)
	result.stderr = testutil.normalizeLineEndings(result.stderr)
	return result
end

local function runLute(...: string): process.ProcessResult
	return runLuteFrom(path.format(workdir), ...)
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
		local result = runLute("--help")
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "format          Format specified Luau files. (experimental)")
		assert.strContains(result.stdout, "Format Options:")
	end)

	suite:case("succeeds without work when a path holds no Luau files", function(assert)
		copyFixture("no-luau-files")

		local result = runLute("format", "--verbose", path.format(workdir))
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Found 0 file(s) to format.")
		assert.strContains(result.stdout, "Formatted 0 of 0 file(s).")
	end)

	suite:case("leaves an empty file empty", function(assert)
		copyFixture("empty-file")
		local target = child("empty.luau")

		local result = runLute("format", "--verbose", target)
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), "")
		assert.strNotContains(result.stdout, `Formatted {target}`)
	end)

	suite:case("discovers Luau files recursively under a directory", function(assert)
		copyFixture("discovery")

		local result = runLute("format", "--verbose", path.format(workdir))
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Trying to format {child("top.luau")}`)
		assert.strContains(result.stdout, `Trying to format {child("nested", "deep.luau")}`)
		assert.strNotContains(result.stdout, `Trying to format {child("ignored.txt")}`)
	end)

	suite:case("skips files and directories excluded by .gitignore", function(assert)
		copyFixture("gitignored")

		local result = runLute("format", "--verbose", path.format(workdir))
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Trying to format {child("src.luau")}`)
		assert.strNotContains(result.stdout, `Trying to format {child("generated.luau")}`)
		assert.strNotContains(result.stdout, `Trying to format {child("vendor", "dep.luau")}`)
	end)

	suite:case("rewrites a file in place when the formatter changes it", function(assert)
		copyFixture("formatting")
		local target = child("unformatted.luau")

		local result = runLute("format", "--verbose", target)
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), FORMATTED)
		assert.strContains(result.stdout, `Formatted {target}`)
		assert.strContains(result.stdout, "Formatted 1 of 1 file(s).")
	end)

	suite:case("leaves a file byte-identical when the formatter reports no change", function(assert)
		copyFixture("formatting")
		local target = child("formatted.luau")

		local result = runLute("format", "--verbose", target)
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(target), FORMATTED)
		assert.strNotContains(result.stdout, `Formatted {target}`)
		assert.strContains(result.stdout, "Formatted 0 of 1 file(s).")
	end)

	suite:case("--check exits 1 for an unformatted file without rewriting it", function(assert)
		copyFixture("formatting")
		local target = child("unformatted.luau")

		local result = runLute("format", "--check", target)
		assert.eq(result.exitcode, 1)
		assert.eq(fs.readFileToString(target), UNFORMATTED)
	end)

	suite:case("skips files matched by lute.format.ignores", function(assert)
		copyFixture("configured-ignores")
		local target = child("unformatted.luau")

		local result = runLute("format", "--verbose", path.format(workdir))
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Skipping {target}`)
		assert.strNotContains(result.stdout, `Trying to format {target}`)
		assert.eq(fs.readFileToString(target), UNFORMATTED)
	end)

	suite:case("skips directories matched by lute.format.ignores", function(assert)
		copyFixture("ignored-directory")

		local result = runLute("format", "--verbose", path.format(workdir))
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Trying to format {child("top.luau")}`)
		assert.strContains(result.stdout, `Skipping {child("nested", "deep.luau")}`)
		assert.strNotContains(result.stdout, `Trying to format {child("nested", "deep.luau")}`)
	end)

	suite:case("reads lute.format.ignores from a config in an ancestor directory", function(assert)
		copyFixture("ancestor-config")
		local project = child("project")

		local result = runLuteFrom(project, "format", "--verbose", ".")
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Formatted 0 of 1 file(s).")
		assert.eq(readNormalizedFile(path.join(project, "unformatted.luau")), UNFORMATTED)
	end)

	suite:case("formats later inputs when an earlier one is ignored", function(assert)
		copyFixture("partially-ignored")
		local ignored = child("ignored-unformatted.luau")
		local included = child("included-unformatted.luau")

		local result = runLute("format", "--verbose", ignored, included)
		assert.eq(result.exitcode, 0)
		assert.eq(fs.readFileToString(ignored), UNFORMATTED)
		assert.eq(fs.readFileToString(included), FORMATTED)
		assert.strContains(result.stdout, "Formatted 1 of 1 file(s).")
	end)

	suite:case("applies lute.format.ignores to explicitly named files", function(assert)
		copyFixture("configured-ignores")
		local target = child("unformatted.luau")

		local result = runLute("format", "--verbose", target)
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, `Skipping {target}`)
		assert.eq(fs.readFileToString(target), UNFORMATTED)
	end)

	suite:case("--check exits 0 when the only unformatted file is ignored", function(assert)
		copyFixture("configured-ignores")

		local result = runLute("format", "--check", path.format(workdir))
		assert.eq(result.exitcode, 0)
	end)

	suite:case("--no-ignore formats a file that lute.format.ignores matches", function(assert)
		copyFixture("configured-ignores")
		local target = child("unformatted.luau")

		local result = runLute("format", "--verbose", "--no-ignore", target)
		assert.eq(result.exitcode, 0)
		assert.strNotContains(result.stdout, `Skipping {target}`)
		assert.eq(fs.readFileToString(target), FORMATTED)
	end)

	suite:case("--no-ignore makes --check exit 1 for an ignored unformatted file", function(assert)
		copyFixture("configured-ignores")
		local target = child("unformatted.luau")

		local result = runLute("format", "--check", "--no-ignore", target)
		assert.eq(result.exitcode, 1)
		assert.eq(fs.readFileToString(target), UNFORMATTED)
	end)

	suite:case("errors when lute.format.ignores is not an array of globs", function(assert)
		copyFixture("invalid-ignores")

		local result = runLute("format", path.format(workdir))
		assert.eq(result.exitcode, 1)
		assert.strContains(result.stderr, "lute.format.ignores must be an array of filepath globs")
		assert.eq(fs.readFileToString(child("unformatted.luau")), UNFORMATTED)
	end)

	suite:case("accepts -c and -v as aliases for --check and --verbose", function(assert)
		copyFixture("formatting")
		local target = child("unformatted.luau")

		local long = runLute("format", "--check", "--verbose", target)
		local short = runLute("format", "-cv", target)
		assert.eq(long.exitcode, 1)
		assert.eq(short.exitcode, long.exitcode)
		assert.eq(short.stdout, long.stdout)
	end)
end)
