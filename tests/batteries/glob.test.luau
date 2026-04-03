local fs = require("@std/fs")
local glob = require("@batteries/glob")
local test = require("@std/test")

type Folder = { [string]: Hierarchy }
type Hierarchy = "file" | Folder

local root = "./test-glob-hierarchy"

local function buildTree(folder: Folder, base: string)
	for name, hierarchy in folder do
		local full = base .. "/" .. name
		if hierarchy == "file" then
			fs.writeStringToFile(full, "content")
		else
			fs.createDirectory(full)
			buildTree(hierarchy, full)
		end
	end
end

local function runGlob(folder: Folder, pattern: string): { string }
	pcall(fs.removeDirectory, root, { recursive = true })
	fs.createDirectory(root)
	buildTree(folder, root)

	local prefix = root .. "/"
	local raw = glob(prefix .. pattern)
	local stripped = {}
	for _, p in raw do
		if string.sub(p, 1, #prefix) == prefix then
			table.insert(stripped, string.sub(p, #prefix + 1))
		else
			error(`path {p} does not start with {prefix}`)
		end
	end
	return stripped
end

test.suite("Glob", function(suite)
	-- literal paths

	suite:case("literalFilePath", function(assert)
		local results = runGlob({
			["hello.txt"] = "file",
		}, "hello.txt")
		assert.eq(results, { "hello.txt" })
	end)

	suite:case("literalPathNotFound", function(assert)
		local results = runGlob({
			["hello.txt"] = "file",
		}, "missing.txt")
		assert.eq(results, {})
	end)

	-- star wildcard

	suite:case("starMatchesAllEntries", function(assert)
		local results = runGlob({
			["a.txt"] = "file",
			["b.txt"] = "file",
			["subdir"] = {},
		}, "*")
		assert.eq(results, { "a.txt", "b.txt", "subdir" })
	end)

	suite:case("starWithExtensionFilter", function(assert)
		local results = runGlob({
			["a.lua"] = "file",
			["b.txt"] = "file",
			["c.lua"] = "file",
		}, "*.lua")
		assert.eq(results, { "a.lua", "c.lua" })
	end)

	suite:case("starDoesNotCrossDirectories", function(assert)
		local results = runGlob({
			["dir"] = {
				["nested.txt"] = "file",
			},
			["top.txt"] = "file",
		}, "*.txt")
		assert.eq(results, { "top.txt" })
	end)

	suite:case("starInNestedDirectory", function(assert)
		local results = runGlob({
			["modules"] = {
				["ModuleA"] = { ["src"] = {} },
				["ModuleB"] = { ["src"] = {} },
				["ModuleC"] = { ["src"] = {} },
			},
		}, "modules/*")
		assert.eq(results, { "modules/ModuleA", "modules/ModuleB", "modules/ModuleC" })
	end)

	suite:case("noMatches", function(assert)
		local results = runGlob({
			["a.txt"] = "file",
		}, "*.lua")
		assert.eq(results, {})
	end)

	-- question mark wildcard

	suite:case("questionMarkMatchesSingleChar", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["a2"] = "file",
			["a12"] = "file",
			["b1"] = "file",
		}, "a?")
		assert.eq(results, { "a1", "a2" })
	end)

	-- character classes

	suite:case("characterClass", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["b1"] = "file",
			["c1"] = "file",
			["d1"] = "file",
		}, "[abc]1")
		assert.eq(results, { "a1", "b1", "c1" })
	end)

	suite:case("negatedCharacterClass", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["b1"] = "file",
			["c1"] = "file",
		}, "[!a]1")
		assert.eq(results, { "b1", "c1" })
	end)

	suite:case("characterRange", function(assert)
		local results = runGlob({
			["a1"] = "file",
			["b1"] = "file",
			["c1"] = "file",
			["z1"] = "file",
		}, "[a-c]1")
		assert.eq(results, { "a1", "b1", "c1" })
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
		assert.eq(results, { "a.txt", "sub/b.txt", "sub/deep/c.txt" })
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
		assert.eq(results, { "a/b/c/x.txt", "a/b/x.txt", "a/x.txt" })
	end)

	suite:case("doubleStarAtEnd", function(assert)
		local results = runGlob({
			["a.txt"] = "file",
			["sub"] = {
				["b.txt"] = "file",
			},
		}, "**")
		assert.eq(results, { "a.txt", "sub", "sub/b.txt" })
	end)

	-- cleanup
	pcall(fs.removeDirectory, root, { recursive = true })
end)
