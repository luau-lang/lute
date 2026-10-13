local fs = require("@std/fs")
local path = require("@std/path")
local publishArtifact = require("@commands/pkg/loom-core/src/publishartifact")
local system = require("@std/system")
local test = require("@std/test")
local unzip = require("@commands/pkg/loom-core/extern/unzip")

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-publish-artifact")
local generatedManifest = 'return { package = { name = "example", version = "1.0.0" } }\n'

local function writeFile(filepath: path.Path, contents: string)
	fs.createDirectory(path.dirname(filepath), { makeParents = true })
	fs.writeStringToFile(filepath, contents)
end

local function readEntry(reader: unzip.ZipReader, name: string): string
	local entry = reader:findEntry(name)
	assert(entry ~= nil, `Missing ZIP entry '{name}'`)
	return reader:extract(entry :: unzip.ZipEntry, { type = "text" }) :: string
end

test.suite("Publish artifact", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("buildsADeterministicZipOfThePublishablePackageFiles", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		writeFile(path.join(packageDirectory, "README.md"), "read me\n")
		writeFile(path.join(packageDirectory, "src", "init.luau"), 'return "package"\n')
		writeFile(path.join(packageDirectory, "assets", "data.bin"), "a\0b")
		writeFile(path.join(packageDirectory, "loom.config.luau"), "return { workspace = {} }\n")
		writeFile(path.join(packageDirectory, "src", "loom.config.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, "loom.lock.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, "src", "loom.lock.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, "Packages", "dependency", "init.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, ".loom", "state"), "state\n")
		writeFile(path.join(packageDirectory, ".git", "objects", "object"), "object\n")
		writeFile(path.join(packageDirectory, ".gitignore"), "ignored\n")
		fs.symbolicLink("README.md", path.join(packageDirectory, "linked-readme"))

		local first = publishArtifact.build(path.format(packageDirectory), generatedManifest)
		local second = publishArtifact.build(path.format(packageDirectory), generatedManifest)
		assert.eq(buffer.tostring(first), buffer.tostring(second))

		local reader = unzip.load(first)
		assert.eq(reader:getStats().fileCount, 4)
		assert.eq(readEntry(reader, "loom.config.luau"), generatedManifest)
		assert.eq(readEntry(reader, "README.md"), "read me\n")
		assert.eq(readEntry(reader, "src/init.luau"), 'return "package"\n')
		assert.eq(readEntry(reader, "assets/data.bin"), "a\0b")
		assert.that(reader:findEntry("Packages/dependency/init.luau") == nil)
		assert.that(reader:findEntry(".git/objects/object") == nil)
		assert.that(reader:findEntry("src/loom.config.luau") == nil)
		assert.that(reader:findEntry("loom.lock.luau") == nil)
		assert.that(reader:findEntry("src/loom.lock.luau") == nil)
		assert.that(reader:findEntry("linked-readme") == nil)
	end)
end)
