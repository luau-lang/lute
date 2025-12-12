local files = require("@commands/lib/files")
local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local tmpdir = system.tmpdir()
local testPath = path.join(tmpdir, "gitignore_test")

test.suite("cli/lib/files", function(suite)
	suite:beforeeach(function()
		if fs.exists(testPath) then
			fs.removedirectory(testPath, { recursive = true })
		end
	end)

	suite:case("parse simple file pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "*.lua\n")

		local shouldIgnorePath = path.join(testPath, "debug.lua")
		fs.writestringtofile(shouldIgnorePath, "")

		local shouldNotIgnorePath = path.join(testPath, "readme.luau")
		fs.writestringtofile(shouldNotIgnorePath, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)

	suite:case("parse directory pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "node_modules/\n")

		local dirPath = path.join(testPath, "node_modules")
		fs.createdirectory(dirPath)
		local shouldIgnoreFile = path.join(dirPath, "package.luau")
		fs.writestringtofile(shouldIgnoreFile, "")

		local nestedDirPath = path.join(testPath, "a", "node_modules")
		fs.createdirectory(nestedDirPath, { makeparents = true })
		local shouldIgnoreNestedFile = path.join(nestedDirPath, "nested_package.luau")
		fs.writestringtofile(shouldIgnoreNestedFile, "")

		local shouldNotIgnoreFile = path.join(testPath, "node_modules.luau")
		fs.writestringtofile(shouldNotIgnoreFile, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)

	suite:case("parse negation pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "*.lua\n!important.lua\n")

		local shouldIgnorePath = path.join(testPath, "debug.lua")
		fs.writestringtofile(shouldIgnorePath, "")

		local shouldNotIgnorePath = path.join(testPath, "important.lua")
		fs.writestringtofile(shouldNotIgnorePath, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)

	suite:case("parse leading double asterisk pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "**/temp/foo\n")

		local subdir = path.join(testPath, "src", "temp", "foo")
		fs.createdirectory(subdir, { makeparents = true })

		local shouldIgnorePath = path.join(subdir, "template.luau")
		fs.writestringtofile(shouldIgnorePath, "")

		local shouldntIgnorePath = path.join(testPath, "src", "temp", "hello.luau")
		fs.writestringtofile(shouldntIgnorePath, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)

	suite:case("parse trailing double asterisk pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "temp/foo/**\n")

		local subdir = path.join(testPath, "temp", "foo", "src")
		fs.createdirectory(subdir, { makeparents = true })

		local shouldIgnorePath = path.join(subdir, "template.luau")
		fs.writestringtofile(shouldIgnorePath, "")

		local shouldIgnorePath2 = path.join(testPath, "temp", "foo", "template.luau")
		fs.writestringtofile(shouldIgnorePath2, "")

		local shouldntIgnorePath = path.join(testPath, "temp", "hello.luau")
		fs.writestringtofile(shouldntIgnorePath, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)

	suite:case("parse middle double asterisk pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "temp/**/foo\n")

		local subdir = path.join(testPath, "temp", "src", "foo")
		fs.createdirectory(subdir, { makeparents = true })

		local shouldIgnorePath = path.join(subdir, "template.luau")
		fs.writestringtofile(shouldIgnorePath, "")

		local subdir2 = path.join(testPath, "temp", "src", "test", "foo")
		fs.createdirectory(subdir2, { makeparents = true })

		local shouldIgnorePath2 = path.join(subdir2, "template.luau")
		fs.writestringtofile(shouldIgnorePath2, "")

		local shouldntIgnorePath = path.join(testPath, "temp", "hello.luau")
		fs.writestringtofile(shouldntIgnorePath, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)

	suite:case("parse rooted pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "/build\n")

		fs.createdirectory(path.join(testPath, "build"), { makeparents = true })

		local shouldIgnorePath = path.join(testPath, "build", "foo.luau")
		fs.writestringtofile(shouldIgnorePath, "")

		fs.createdirectory(path.join(testPath, "src", "build"), { makeparents = true })

		local shouldNotIgnorePath = path.join(testPath, "src", "build", "bar.luau")
		fs.writestringtofile(shouldNotIgnorePath, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)

	suite:case("parse question mark pattern", function(assert)
		-- Setup
		fs.createdirectory(testPath)
		local gitignorePath = path.join(testPath, ".gitignore")
		fs.writestringtofile(gitignorePath, "file?.luau\n")

		local shouldIgnorePath1 = path.join(testPath, "file1.luau")
		fs.writestringtofile(shouldIgnorePath1, "")

		local shouldIgnorePath2 = path.join(testPath, "fileA.luau")
		fs.writestringtofile(shouldIgnorePath2, "")

		local shouldNotIgnorePath = path.join(testPath, "file10.luau")
		fs.writestringtofile(shouldNotIgnorePath, "")

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
		fs.removedirectory(testPath, { recursive = true })
	end)
end)

test.run()
