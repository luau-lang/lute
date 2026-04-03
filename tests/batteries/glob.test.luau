local fs = require("@std/fs")
local glob = require("@batteries/glob")
local path = require("@std/path")
local test = require("@std/test")

type Folder = { [string]: Hierarchy }
type Hierarchy = "file" | Folder

local root = "./test-glob-hierarchy"

local function buildTree(folder: Folder, base: string)
	for name, hierarchy in folder do
		local full = path.format(path.join(base, name))
		if hierarchy == "file" then
			fs.writeStringToFile(full, "content")
		else
			fs.createDirectory(full)
			buildTree(hierarchy :: Folder, full)
		end
	end
end

-- Asserts that actual paths match expected paths written with forward slashes,
-- normalizing the expected values to the platform's native separator.
local function assertPaths(assert: any, actual: { string }, expected: { string })
	local normalized = {}
	for _, s in expected do
		table.insert(normalized, path.format(path.parse(s)))
	end
	assert.eq(actual, normalized)
end

local function runGlob(folder: Folder, pattern: string): { string }
	pcall(fs.removeDirectory, root, { recursive = true })
	fs.createDirectory(root)
	buildTree(folder, root)

	local raw = glob.discover(path.join(root, pattern))
	local stripped = {}
	for _, result in raw do
		local rel = path.relative(root, result)
		if #rel.parts > 0 and rel.parts[1] == ".." then
			error(`path {result} is not under {root} - accidental root escape`)
		end
		table.insert(stripped, path.format(rel))
	end
	return stripped
end

test.suite("Glob", function(suite)
	-- literal paths

	suite:case("literalFilePath", function(assert)
		local results = runGlob({
			["hello.txt"] = "file",
		}, "hello.txt")
		assertPaths(assert, results, { "hello.txt" })
	end)

	suite:case("literalPathNotFound", function(assert)
		local results = runGlob({
			["hello.txt"] = "file",
		}, "missing.txt")
		assertPaths(assert, results, {})
	end)

	-- star wildcard

	suite:case("starMatchesAllEntries", function(assert)
		local results = runGlob({
			["a.txt"] = "file",
			["b.txt"] = "file",
			["subdir"] = {},
		}, "*")
		assertPaths(assert, results, { "a.txt", "b.txt", "subdir" })
	end)

	suite:case("starWithExtensionFilter", function(assert)
		local results = runGlob({
			["a.lua"] = "file",
			["b.txt"] = "file",
			["c.lua"] = "file",
		}, "*.lua")
		assertPaths(assert, results, { "a.lua", "c.lua" })
	end)

	suite:case("starDoesNotCrossDirectories", function(assert)
		local results = runGlob({
			["dir"] = {
				["nested.txt"] = "file",
			},
			["top.txt"] = "file",
		}, "*.txt")
		assertPaths(assert, results, { "top.txt" })
	end)

	suite:case("starInNestedDirectory", function(assert)
		local results = runGlob({
			["modules"] = {
				["ModuleA"] = { ["src"] = {} },
				["ModuleB"] = { ["src"] = {} },
				["ModuleC"] = { ["src"] = {} },
			},
		}, "modules/*")
		assertPaths(assert, results, { "modules/ModuleA", "modules/ModuleB", "modules/ModuleC" })
	end)

	suite:case("noMatches", function(assert)
		local results = runGlob({
			["a.txt"] = "file",
		}, "*.lua")
		assertPaths(assert, results, {})
	end)

	-- question mark wildcard

	suite:case("questionMarkMatchesSingleChar", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["a2"] = "file",
			["a12"] = "file",
			["b1"] = "file",
		}, "a?")
		assertPaths(assert, results, { "a1", "a2" })
	end)

	-- character classes

	suite:case("characterClass", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["b1"] = "file",
			["c1"] = "file",
			["d1"] = "file",
		}, "[abc]1")
		assertPaths(assert, results, { "a1", "b1", "c1" })
	end)

	suite:case("negatedCharacterClass", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["b1"] = "file",
			["c1"] = "file",
		}, "[!a]1")
		assertPaths(assert, results, { "b1", "c1" })
	end)

	suite:case("characterRange", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["b1"] = "file",
			["c1"] = "file",
			["z1"] = "file",
		}, "[a-c]1")
		assertPaths(assert, results, { "a1", "b1", "c1" })
	end)

	-- double star

	suite:case("doubleStarRecursive", function(assert)
		local results = runGlob({
			["a.txt"] = "file",
			["sub"] = {
				["b.txt"] = "file",
				["deep"] = {
					["c.txt"] = "file",
				},
			},
		}, "**/*.txt")
		assertPaths(assert, results, { "a.txt", "sub/b.txt", "sub/deep/c.txt" })
	end)

	suite:case("doubleStarInMiddle", function(assert)
		local results = runGlob({
			["a"] = {
				["x.txt"] = "file",
				["b"] = {
					["x.txt"] = "file",
					["c"] = {
						["x.txt"] = "file",
					},
				},
			},
		}, "a/**/x.txt")
		assertPaths(assert, results, { "a/b/c/x.txt", "a/b/x.txt", "a/x.txt" })
	end)

	suite:case("doubleStarAtEnd", function(assert)
		local results = runGlob({
			["a.txt"] = "file",
			["sub"] = {
				["b.txt"] = "file",
			},
		}, "**")
		assertPaths(assert, results, { "a.txt", "sub", "sub/b.txt" })
	end)

	-- cleanup
	pcall(fs.removeDirectory, root, { recursive = true })
end)

test.suite("GlobMatch", function(suite)
	-- star wildcard

	suite:case("starMatchesFilename", function(assert)
		assert.eq(glob.match("*.txt", "hello.txt"), true)
	end)

	suite:case("starDoesNotCrossDirectories", function(assert)
		assert.eq(glob.match("*.txt", "dir/hello.txt"), false)
	end)

	suite:case("starInNestedPattern", function(assert)
		assert.eq(glob.match("src/*.lua", "src/main.lua"), true)
		assert.eq(glob.match("src/*.lua", "src/lib/main.lua"), false)
	end)

	suite:case("starMatchesEmptySequence", function(assert)
		assert.eq(glob.match("a*", "a"), true)
	end)

	-- question mark

	suite:case("questionMarkMatchesSingleChar", function(assert)
		assert.eq(glob.match("a?", "a1"), true)
		assert.eq(glob.match("a?", "a12"), false)
		assert.eq(glob.match("a?", "a"), false)
	end)

	-- character classes

	suite:case("characterClass", function(assert)
		assert.eq(glob.match("[abc].txt", "a.txt"), true)
		assert.eq(glob.match("[abc].txt", "d.txt"), false)
	end)

	suite:case("negatedCharacterClass", function(assert)
		assert.eq(glob.match("[!a].txt", "b.txt"), true)
		assert.eq(glob.match("[!a].txt", "a.txt"), false)
	end)

	suite:case("characterRange", function(assert)
		assert.eq(glob.match("[a-c].txt", "b.txt"), true)
		assert.eq(glob.match("[a-c].txt", "z.txt"), false)
	end)

	-- double star

	suite:case("doubleStarMatchesAcrossDirectories", function(assert)
		assert.eq(glob.match("**/*.txt", "a.txt"), true)
		assert.eq(glob.match("**/*.txt", "sub/b.txt"), true)
		assert.eq(glob.match("**/*.txt", "sub/deep/c.txt"), true)
	end)

	suite:case("doubleStarInMiddle", function(assert)
		assert.eq(glob.match("a/**/x.txt", "a/x.txt"), true)
		assert.eq(glob.match("a/**/x.txt", "a/b/x.txt"), true)
		assert.eq(glob.match("a/**/x.txt", "a/b/c/x.txt"), true)
		assert.eq(glob.match("a/**/x.txt", "b/x.txt"), false)
	end)

	suite:case("doubleStarAtEnd", function(assert)
		assert.eq(glob.match("src/**", "src/a.txt"), true)
		assert.eq(glob.match("src/**", "src/sub/b.txt"), true)
	end)

	-- literal path

	suite:case("literalMatch", function(assert)
		assert.eq(glob.match("hello.txt", "hello.txt"), true)
		assert.eq(glob.match("hello.txt", "world.txt"), false)
	end)

	suite:case("literalNestedMatch", function(assert)
		assert.eq(glob.match("src/main.lua", "src/main.lua"), true)
		assert.eq(glob.match("src/main.lua", "lib/main.lua"), false)
	end)

	-- no match

	suite:case("mismatchedDepth", function(assert)
		assert.eq(glob.match("a/b", "a/b/c"), false)
		assert.eq(glob.match("a/b/c", "a/b"), false)
	end)
end)
