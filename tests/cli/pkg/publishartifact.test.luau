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

local function writePackageManifest(packageDirectory: path.Path, contents: string?): path.Path
	local manifestPath = path.join(packageDirectory, "loom.config.luau")
	writeFile(manifestPath, contents or "return { workspace = {} }\n")
	return manifestPath
end

local function buildArtifact(packageDirectory: path.Path, sourceManifestPath: path.Path, options: any?): buffer
	return publishArtifact.build(
		path.format(packageDirectory),
		path.format(sourceManifestPath),
		generatedManifest,
		options
	)
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
		local sourceManifestPath = writePackageManifest(packageDirectory)
		writeFile(path.join(packageDirectory, "src", "loom.config.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, "loom.lock.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, "src", "loom.lock.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, "Packages", "dependency", "init.luau"), "return {}\n")
		writeFile(path.join(packageDirectory, ".loom", "state"), "state\n")
		writeFile(path.join(packageDirectory, ".git", "objects", "object"), "object\n")
		writeFile(path.join(packageDirectory, ".gitignore"), "ignored\n")

		local first = buildArtifact(packageDirectory, sourceManifestPath)
		local second = buildArtifact(packageDirectory, sourceManifestPath)
		assert.eq(buffer.tostring(first), buffer.tostring(second))

		local reader = unzip.load(first)
		assert.eq(reader:getStats().fileCount, 8)
		assert.eq(readEntry(reader, "loom.config.luau"), generatedManifest)
		assert.that(reader:findEntry("loom.config.luau.orig") == nil)
		assert.eq(readEntry(reader, "README.md"), "read me\n")
		assert.eq(readEntry(reader, "src/init.luau"), 'return "package"\n')
		assert.eq(readEntry(reader, "assets/data.bin"), "a\0b")
		assert.eq(readEntry(reader, "src/loom.config.luau"), "return {}\n")
		assert.eq(readEntry(reader, "loom.lock.luau"), "return {}\n")
		assert.eq(readEntry(reader, "src/loom.lock.luau"), "return {}\n")
		assert.eq(readEntry(reader, "Packages/dependency/init.luau"), "return {}\n")
		assert.that(reader:findEntry(".loom/state") == nil)
		assert.that(reader:findEntry(".git/objects/object") == nil)
		assert.that(reader:findEntry(".gitignore") == nil)
	end)

	suite:case("includesHiddenFilesExplicitlySelectedByFiles", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)
		writeFile(path.join(packageDirectory, "README.md"), "published\n")
		writeFile(path.join(packageDirectory, ".gitignore"), "ignored\n")
		writeFile(path.join(packageDirectory, ".well-known", "config"), "config\n")

		local artifact = buildArtifact(packageDirectory, sourceManifestPath, {
			files = { "README.md", ".gitignore", ".well-known/" },
		})
		local reader = unzip.load(artifact)
		assert.eq(reader:getStats().fileCount, 4)
		assert.eq(readEntry(reader, "README.md"), "published\n")
		assert.eq(readEntry(reader, ".gitignore"), "ignored\n")
		assert.eq(readEntry(reader, ".well-known/config"), "config\n")
	end)

	suite:case("rejectsSymlinksInProjectSource", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)
		writeFile(path.join(packageDirectory, "source.luau"), "return {}\n")
		fs.symbolicLink("source.luau", path.join(packageDirectory, "linked-source.luau"))

		assert.throwsWith("Symlinks in project source are not supported", function()
			buildArtifact(packageDirectory, sourceManifestPath)
		end)
	end)

	suite:case("excludesTheSpecifiedSourceManifest", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = path.join(packageDirectory, "source-manifest.luau")
		writeFile(sourceManifestPath, "return { workspace = {} }\n")
		writeFile(path.join(packageDirectory, "init.luau"), 'return "package"\n')

		local artifact = buildArtifact(packageDirectory, sourceManifestPath)
		local reader = unzip.load(artifact)
		assert.eq(readEntry(reader, "loom.config.luau"), generatedManifest)
		assert.eq(readEntry(reader, "init.luau"), 'return "package"\n')
		assert.that(reader:findEntry("source-manifest.luau") == nil)
	end)

	suite:case("usesContentRootAsTheArtifactRoot", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		writeFile(path.join(packageDirectory, "README.md"), "not published\n")
		local sourceManifestPath = writePackageManifest(packageDirectory)
		writeFile(path.join(packageDirectory, "src", "init.luau"), 'return "package"\n')
		writeFile(path.join(packageDirectory, "src", "assets", "data.bin"), "a\0b")

		local artifact = buildArtifact(packageDirectory, sourceManifestPath, { contentRoot = "src" })
		local reader = unzip.load(artifact)
		assert.eq(reader:getStats().fileCount, 3)
		assert.eq(readEntry(reader, "loom.config.luau"), generatedManifest)
		assert.eq(readEntry(reader, "init.luau"), 'return "package"\n')
		assert.eq(readEntry(reader, "assets/data.bin"), "a\0b")
		assert.that(reader:findEntry("src/init.luau") == nil)
		assert.that(reader:findEntry("README.md") == nil)
	end)

	suite:case("rejectsAContentRootFileThatCollidesWithTheGeneratedManifest", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)
		writeFile(path.join(packageDirectory, "src", "loom.config.luau"), "return { nested = {} }\n")

		assert.throwsWith(
			"Cannot publish file 'loom.config.luau': archive path is reserved for the generated package manifest; rename the source file",
			function()
				buildArtifact(packageDirectory, sourceManifestPath, { contentRoot = "src" })
			end
		)
	end)

	suite:case("filtersContentRootWithRotrieverOverridePatterns", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)

		writeFile(path.join(packageDirectory, "src", "root.txt"), "root\n")
		writeFile(path.join(packageDirectory, "src", "nested", "root.txt"), "nested root\n")
		writeFile(path.join(packageDirectory, "src", "nested", "module.luau"), "module\n")
		writeFile(path.join(packageDirectory, "src", "nested", "module.spec.luau"), "spec\n")
		writeFile(path.join(packageDirectory, "src", "nested", "__tests__", "helper.luau"), "test helper\n")
		writeFile(path.join(packageDirectory, "src", "some", "modules", "inner.txt"), "module directory\n")
		writeFile(path.join(packageDirectory, "src", "docs", "guide.md"), "guide\n")
		writeFile(path.join(packageDirectory, "src", "docs", "nested", "guide.txt"), "nested guide\n")
		writeFile(path.join(packageDirectory, "src", "assets", "a1.txt"), "a\n")
		writeFile(path.join(packageDirectory, "src", "assets", "b2.txt"), "b\n")
		writeFile(path.join(packageDirectory, "src", "assets", "c3.txt"), "c\n")
		writeFile(path.join(packageDirectory, "src", "a", "b", "direct.txt"), "direct\n")
		writeFile(path.join(packageDirectory, "src", "a", "x", "b", "nested.txt"), "nested\n")
		writeFile(path.join(packageDirectory, "src", "foo", "bar", "matched.txt"), "matched\n")

		local artifact = buildArtifact(packageDirectory, sourceManifestPath, {
			contentRoot = "src",
			files = {
				"/root.txt",
				"nested/*.luau",
				"modules/",
				"docs/**",
				"assets/[ab]?.txt",
				"a/**/b",
				"**/foo/bar",
				"!**/*.spec.luau",
				"!**/__tests__/",
			},
		})
		local reader = unzip.load(artifact)
		assert.eq(reader:getStats().fileCount, 11)
		assert.eq(readEntry(reader, "loom.config.luau"), generatedManifest)
		assert.eq(readEntry(reader, "root.txt"), "root\n")
		assert.eq(readEntry(reader, "nested/module.luau"), "module\n")
		assert.eq(readEntry(reader, "docs/guide.md"), "guide\n")
		assert.eq(readEntry(reader, "docs/nested/guide.txt"), "nested guide\n")
		assert.eq(readEntry(reader, "assets/a1.txt"), "a\n")
		assert.eq(readEntry(reader, "assets/b2.txt"), "b\n")
		assert.that(reader:findEntry("nested/root.txt") == nil)
		assert.that(reader:findEntry("nested/module.spec.luau") == nil)
		assert.that(reader:findEntry("nested/__tests__/helper.luau") == nil)
		assert.eq(readEntry(reader, "some/modules/inner.txt"), "module directory\n")
		assert.that(reader:findEntry("assets/c3.txt") == nil)
		assert.eq(readEntry(reader, "a/b/direct.txt"), "direct\n")
		assert.eq(readEntry(reader, "a/x/b/nested.txt"), "nested\n")
		assert.eq(readEntry(reader, "foo/bar/matched.txt"), "matched\n")
	end)

	suite:case("allowsALaterPatternToRestoreAFileInAnExcludedDirectory", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)
		writeFile(path.join(packageDirectory, "generated", "discard.luau"), "discard\n")
		writeFile(path.join(packageDirectory, "generated", "keep.luau"), "keep\n")

		local artifact = buildArtifact(packageDirectory, sourceManifestPath, {
			files = { "**", "!generated/", "generated/keep.luau" },
		})
		local reader = unzip.load(artifact)
		assert.eq(reader:getStats().fileCount, 2)
		assert.eq(readEntry(reader, "generated/keep.luau"), "keep\n")
		assert.that(reader:findEntry("generated/discard.luau") == nil)
	end)

	suite:case("rejectsContentRootOutsideThePackage", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)

		assert.throwsWith("'content_root' must stay inside the package directory", function()
			buildArtifact(packageDirectory, sourceManifestPath, { contentRoot = "../outside" })
		end)
	end)

	suite:case("rejectsWindowsContentRoots", function(assert)
		if not system.win32 then
			return
		end

		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)

		assert.throwsWith("'content_root' must stay inside the package directory", function()
			buildArtifact(packageDirectory, sourceManifestPath, { contentRoot = "..\\outside" })
		end)
		assert.throwsWith("'content_root' must be relative to the package directory", function()
			buildArtifact(packageDirectory, sourceManifestPath, { contentRoot = "C:/outside" })
		end)
	end)

	suite:case("includesGitignoredFiles", function(assert)
		local packageDirectory = path.join(workingDirectory, "package")
		fs.createDirectory(packageDirectory)
		local sourceManifestPath = writePackageManifest(packageDirectory)
		writeFile(path.join(packageDirectory, ".gitignore"), "ignored.txt\nbuild/\n")
		writeFile(path.join(packageDirectory, "README.md"), "published\n")
		writeFile(path.join(packageDirectory, "ignored.txt"), "published\n")
		writeFile(path.join(packageDirectory, "build", "output.luau"), "published\n")
		writeFile(path.join(packageDirectory, "src", "init.luau"), 'return "package"\n')
		writeFile(path.join(packageDirectory, "src", "package.spec.luau"), "published\n")
		writeFile(path.join(packageDirectory, "src", "__tests__", "helper.luau"), "published\n")

		local artifact = buildArtifact(packageDirectory, sourceManifestPath)
		local reader = unzip.load(artifact)
		assert.eq(reader:getStats().fileCount, 7)
		assert.eq(readEntry(reader, "loom.config.luau"), generatedManifest)
		assert.that(reader:findEntry(".gitignore") == nil)
		assert.eq(readEntry(reader, "README.md"), "published\n")
		assert.eq(readEntry(reader, "ignored.txt"), "published\n")
		assert.eq(readEntry(reader, "build/output.luau"), "published\n")
		assert.eq(readEntry(reader, "src/init.luau"), 'return "package"\n')
		assert.eq(readEntry(reader, "src/package.spec.luau"), "published\n")
		assert.eq(readEntry(reader, "src/__tests__/helper.luau"), "published\n")
	end)
end)
