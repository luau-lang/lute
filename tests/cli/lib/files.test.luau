local files = require("@commands/lib/files")
local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local tmpdir = system.tmpdir()
local testPath = path.join(tmpdir, "gitignore_test")

test.suite("CliLibFiles", function(suite)
	suite:beforeEach(function()
		if fs.exists(testPath) then
			fs.removeDirectory(testPath, { recursive = true })
		end
	end)

	suite:case("parseSimpleFilePattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "*.lua\n")

		local shouldIgnorePath = path.join(testPath, "debug.lua")
		fs.writeStringToFile(shouldIgnorePath, "")

		local shouldNotIgnorePath = path.join(testPath, "readme.luau")
		fs.writeStringToFile(shouldNotIgnorePath, "")

		local shouldNotIgnoreDirectory = path.join(testPath, "lua")
		fs.createDirectory(shouldNotIgnoreDirectory)
		local shouldNotIgnoreNestedPath = path.join(shouldNotIgnoreDirectory, "readme.luau")
		fs.writeStringToFile(shouldNotIgnoreNestedPath, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })

		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[path.format(shouldIgnorePath)], nil)
		assert.eq(resultPaths[path.format(shouldNotIgnorePath)], true)
		assert.eq(resultPaths[path.format(shouldNotIgnoreNestedPath)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)

	suite:case("parseDirectoryPattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "node_modules/\n")

		local dirPath = path.join(testPath, "node_modules")
		fs.createDirectory(dirPath)
		local shouldIgnoreFile = path.join(dirPath, "package.luau")
		fs.writeStringToFile(shouldIgnoreFile, "")

		local nestedDirPath = path.join(testPath, "a", "node_modules")
		fs.createDirectory(nestedDirPath, { makeParents = true })
		local shouldIgnoreNestedFile = path.join(nestedDirPath, "nested_package.luau")
		fs.writeStringToFile(shouldIgnoreNestedFile, "")

		local shouldNotIgnoreFile = path.join(testPath, "node_modules.luau")
		fs.writeStringToFile(shouldNotIgnoreFile, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })

		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[path.format(shouldIgnoreFile)], nil)
		assert.eq(resultPaths[path.format(shouldIgnoreNestedFile)], nil)
		assert.eq(resultPaths[path.format(shouldNotIgnoreFile)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)

	suite:case("parseNegationPattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "*.lua\n!important.lua\n")

		local shouldIgnorePath = path.join(testPath, "debug.lua")
		fs.writeStringToFile(shouldIgnorePath, "")

		local shouldNotIgnorePath = path.join(testPath, "important.lua")
		fs.writeStringToFile(shouldNotIgnorePath, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })

		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[path.format(shouldIgnorePath)], nil)
		assert.eq(resultPaths[path.format(shouldNotIgnorePath)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)

	suite:case("parseLeadingDoubleAsteriskPattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "**/temp/foo\n")

		local subdir = path.join(testPath, "src", "temp", "foo")
		fs.createDirectory(subdir, { makeParents = true })

		local shouldIgnorePath = path.join(subdir, "template.luau")
		fs.writeStringToFile(shouldIgnorePath, "")

		local shouldntIgnorePath = path.join(testPath, "src", "temp", "hello.luau")
		fs.writeStringToFile(shouldntIgnorePath, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })

		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[path.format(shouldIgnorePath)], nil)
		assert.eq(resultPaths[path.format(shouldntIgnorePath)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)

	suite:case("parseTrailingDoubleAsteriskPattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "temp/foo/**\n")

		local subdir = path.join(testPath, "temp", "foo", "src")
		fs.createDirectory(subdir, { makeParents = true })

		local shouldIgnorePath = path.join(subdir, "template.luau")
		fs.writeStringToFile(shouldIgnorePath, "")

		local shouldIgnorePath2 = path.join(testPath, "temp", "foo", "template.luau")
		fs.writeStringToFile(shouldIgnorePath2, "")

		local shouldntIgnorePath = path.join(testPath, "temp", "hello.luau")
		fs.writeStringToFile(shouldntIgnorePath, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })

		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[path.format(shouldIgnorePath)], nil)
		assert.eq(resultPaths[path.format(shouldIgnorePath2)], nil)
		assert.eq(resultPaths[path.format(shouldntIgnorePath)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)

	suite:case("parseMiddleDoubleAsteriskPattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "temp/**/foo\n")

		local subdir = path.join(testPath, "temp", "src", "foo")
		fs.createDirectory(subdir, { makeParents = true })

		local shouldIgnorePath = path.join(subdir, "template.luau")
		fs.writeStringToFile(shouldIgnorePath, "")

		local subdir2 = path.join(testPath, "temp", "src", "test", "foo")
		fs.createDirectory(subdir2, { makeParents = true })

		local shouldIgnorePath2 = path.join(subdir2, "template.luau")
		fs.writeStringToFile(shouldIgnorePath2, "")

		local shouldntIgnorePath = path.join(testPath, "temp", "hello.luau")
		fs.writeStringToFile(shouldntIgnorePath, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })

		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[path.format(shouldIgnorePath)], nil)
		assert.eq(resultPaths[path.format(shouldIgnorePath2)], nil)
		assert.eq(resultPaths[path.format(shouldntIgnorePath)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)

	suite:case("parseRootedPattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "/build\n")

		fs.createDirectory(path.join(testPath, "build"), { makeParents = true })

		local shouldIgnorePath = path.join(testPath, "build", "foo.luau")
		fs.writeStringToFile(shouldIgnorePath, "")

		fs.createDirectory(path.join(testPath, "src", "build"), { makeParents = true })

		local shouldNotIgnorePath = path.join(testPath, "src", "build", "bar.luau")
		fs.writeStringToFile(shouldNotIgnorePath, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })

		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[(path.format(shouldIgnorePath))], nil)
		assert.eq(resultPaths[path.format(shouldNotIgnorePath)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)

	suite:case("parseQuestionMarkPattern", function(assert)
		-- Setup
		fs.createDirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writeStringToFile(gitignorePath, "file?.luau\n")

		local shouldIgnorePath1 = path.join(testPath, "file1.luau")
		fs.writeStringToFile(shouldIgnorePath1, "")

		local shouldIgnorePath2 = path.join(testPath, "fileA.luau")
		fs.writeStringToFile(shouldIgnorePath2, "")

		local shouldNotIgnorePath = path.join(testPath, "file10.luau")
		fs.writeStringToFile(shouldNotIgnorePath, "")

		-- Do
		local results = files.getSourceFiles({ path.format(testPath) })
		-- Check
		local resultPaths = {}
		for _, p in results do
			resultPaths[path.format(p)] = true
		end
		assert.eq(resultPaths[path.format(shouldIgnorePath1)], nil)
		assert.eq(resultPaths[path.format(shouldIgnorePath2)], nil)
		assert.eq(resultPaths[path.format(shouldNotIgnorePath)], true)

		-- Teardown
		fs.removeDirectory(testPath, { recursive = true })
	end)
end)
