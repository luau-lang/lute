local system = require("@std/system")
local test = require("@std/test")

local path = require("@std/path")
local posix = require("@std/path/posix")

test.suite("PathPosixParseSuite", function(suite)
	suite:case("parsePosixAbsolutePath", function(assert)
		local result = path.posix.parse("/home/user/documents/file.txt")
		assert.that(result.absolute)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parsePosixRelativePath", function(assert)
		local result = path.posix.parse("documents/file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("parseEmptyString", function(assert)
		local result = path.posix.parse("")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("parseRootPath", function(assert)
		local result = path.posix.parse("/")
		assert.that(result.absolute)
		assert.eq(#result.parts, 0)
	end)

	suite:case("parseSingleFile", function(assert)
		local result = path.posix.parse("file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "file.txt")
	end)

	suite:case("parsePathobjReturnsSame", function(assert)
		local originalPath: posix.Path = setmetatable({
			parts = { "folder", "file.txt" },
			absolute = false,
		}, posix.pathmt)
		local result = path.posix.parse(originalPath)
		assert.eq(result, originalPath)
	end)
end)

test.suite("PathPosixBasenameSuite", function(suite)
	suite:case("basenamePosixAbsolutePath", function(assert)
		local result = path.posix.basename("/home/user/documents/file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basenamePosixRelativePath", function(assert)
		local result = path.posix.basename("documents/file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basenameSingleFile", function(assert)
		local result = path.posix.basename("file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basenameDirectoryNoExtension", function(assert)
		local result = path.posix.basename("/home/user/documents")
		assert.eq(result, "documents")
	end)

	suite:case("basenameEmptyPath", function(assert)
		local result = path.posix.basename("")
		assert.eq(result, nil)
	end)

	suite:case("basenameRootPath", function(assert)
		local result = path.posix.basename("/")
		assert.eq(result, nil)
	end)

	suite:case("basenamePathobj", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "folder", "subfolder", "file.txt" },
			absolute = false,
		}, posix.pathmt)
		local result = path.posix.basename(pathobj)
		assert.eq(result, "file.txt")
	end)
end)

test.suite("PathPosixFormatSuite", function(suite)
	suite:case("formatPosixAbsolutePath", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "home", "user", "documents", "file.txt" },
			absolute = true,
		}, posix.pathmt)
		local result = path.posix.format(pathobj)
		assert.eq(result, "/home/user/documents/file.txt")
	end)

	suite:case("formatPosixRelativePath", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "documents", "file.txt" },
			absolute = false,
		}, posix.pathmt)
		local result = path.posix.format(pathobj)
		assert.eq(result, "documents/file.txt")
	end)

	suite:case("formatEmptyRelativePath", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = {},
			absolute = false,
		}, posix.pathmt)
		local result = path.posix.format(pathobj)
		assert.eq(result, ".")
	end)

	suite:case("formatRootPath", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = {},
			absolute = true,
		}, posix.pathmt)
		local result = path.posix.format(pathobj)
		assert.eq(result, "/")
	end)

	suite:case("formatStringReturnsSame", function(assert)
		local result = path.posix.format("/home/user/file.txt")
		assert.eq(result, "/home/user/file.txt")
	end)
end)

test.suite("PathPosixDirnameSuite", function(suite)
	suite:case("dirnamePosixAbsolutePath", function(assert)
		local result = path.posix.dirname("/home/user/documents/file.txt")
		assert.eq(result, "/home/user/documents")
	end)

	suite:case("dirnamePosixRelativePath", function(assert)
		local result = path.posix.dirname("documents/file.txt")
		assert.eq(result, "documents")
	end)

	suite:case("dirnameSingleFile", function(assert)
		local result = path.posix.dirname("file.txt")
		assert.eq(result, ".")
	end)

	suite:case("dirnameNestedDirectory", function(assert)
		local result = path.posix.dirname("/home/user/documents/subfolder")
		assert.eq(result, "/home/user/documents")
	end)

	suite:case("dirnameEmptyPath", function(assert)
		local result = path.posix.dirname("")
		assert.eq(result, ".")
	end)

	suite:case("dirnameRootPath", function(assert)
		local result = path.posix.dirname("/")
		assert.eq(result, "/")
	end)

	suite:case("dirnamePathobj", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "folder", "subfolder", "file.txt" },
			absolute = false,
		}, posix.pathmt)
		local result = path.posix.dirname(pathobj)
		assert.eq(result, "folder/subfolder")
	end)
end)

test.suite("PathPosixExtnameSuite", function(suite)
	suite:case("extnameSimpleExtension", function(assert)
		local result = path.posix.extname("/home/user/file.txt")
		assert.eq(result, ".txt")
	end)

	suite:case("extnameMultipleDots", function(assert)
		local result = path.posix.extname("/home/user/archive.tar.gz")
		assert.eq(result, ".gz")
	end)

	suite:case("extnameNoExtension", function(assert)
		local result = path.posix.extname("/home/user/README")
		assert.eq(result, "")
	end)

	suite:case("extnameHiddenFileWithExtension", function(assert)
		local result = path.posix.extname("/home/user/.bashrc")
		assert.eq(result, "")
	end)

	suite:case("extnameHiddenFileWithRealExtension", function(assert)
		local result = path.posix.extname("/home/user/.config.json")
		assert.eq(result, ".json")
	end)

	suite:case("extnameDirectoryPath", function(assert)
		local result = path.posix.extname("/home/user/documents")
		assert.eq(result, "")
	end)

	suite:case("extnameEmptyPath", function(assert)
		local result = path.posix.extname("")
		assert.eq(result, "")
	end)

	suite:case("extnameRootPath", function(assert)
		local result = path.posix.extname("/")
		assert.eq(result, "")
	end)

	suite:case("extnamePathobj", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "folder", "file.pdf" },
			absolute = false,
		}, posix.pathmt)
		local result = path.posix.extname(pathobj)
		assert.eq(result, ".pdf")
	end)

	suite:case("extnameDotOnly", function(assert)
		local result = path.posix.extname("/home/user/file.")
		assert.eq(result, ".")
	end)

	suite:case("extnameFilenameIsDot", function(assert)
		local result = path.posix.extname("/home/user/.")
		assert.eq(result, "")
	end)

	suite:case("extnameFilenameIsDotdot", function(assert)
		local result = path.posix.extname("/home/user/..")
		assert.eq(result, "")
	end)
end)

test.suite("PathPosixisAbsoluteSuite", function(suite)
	suite:case("absolutePosixAbsolutePath", function(assert)
		local result = path.posix.isAbsolute("/home/user/documents/file.txt")
		assert.that(result)
	end)

	suite:case("absolutePosixRelativePath", function(assert)
		local result = path.posix.isAbsolute("documents/file.txt")
		assert.eq(result, false)
	end)

	suite:case("absoluteRootPath", function(assert)
		local result = path.posix.isAbsolute("/")
		assert.that(result)
	end)

	suite:case("absoluteEmptyPath", function(assert)
		local result = path.posix.isAbsolute("")
		assert.eq(result, false)
	end)

	suite:case("absolutePathobjAbsolute", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "home", "user", "file.txt" },
			absolute = true,
		}, posix.pathmt)
		local result = path.posix.isAbsolute(pathobj)
		assert.that(result)
	end)

	suite:case("absolutePathobjRelative", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "folder", "file.txt" },
			absolute = false,
		}, posix.pathmt)
		local result = path.posix.isAbsolute(pathobj)
		assert.eq(result, false)
	end)
end)

test.suite("PathPosixNormalizeSuite", function(suite)
	suite:case("normalizeRemovesCurrentDirectory", function(assert)
		local result = path.posix.normalize("/home/./user/documents")
		assert.that(result.absolute)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
	end)

	suite:case("normalizeResolvesParentDirectory", function(assert)
		local result = path.posix.normalize("/home/user/../documents")
		assert.that(result.absolute)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "documents")
	end)

	suite:case("normalizeMultipleDots", function(assert)
		local result = path.posix.normalize("/home/user/./documents/../files/./")
		assert.that(result.absolute)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "files")
	end)

	suite:case("normalizeRelativePath", function(assert)
		local result = path.posix.normalize("documents/./subfolder/../file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("normalizeRemovesEmptySegments", function(assert)
		local result = path.posix.normalize("/home//user///documents")
		assert.that(result.absolute)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
	end)

	suite:case("normalizeParentBeyondRoot", function(assert)
		local result = path.posix.normalize("/home/../..")
		assert.that(result.absolute)
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalizeEmptyPath", function(assert)
		local result = path.posix.normalize("")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalizeOnlyDots", function(assert)
		local result = path.posix.normalize("./././.")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalizePathobj", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "home", ".", "user", "..", "documents" },
			absolute = true,
		}, posix.pathmt)
		local result = path.posix.normalize(pathobj)
		assert.that(result.absolute)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "documents")
	end)

	suite:case("normalizeParentDirectoryOnly", function(assert)
		local result = path.posix.normalize("..")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "..")
	end)

	suite:case("normalizeMultipleParentDirectories", function(assert)
		local result = path.posix.normalize("../../..")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "..")
		assert.eq(result.parts[3], "..")
	end)

	suite:case("normalizeParentThenFolder", function(assert)
		local result = path.posix.normalize("../folder/file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "folder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("normalizeMultipleParentsThenFolder", function(assert)
		local result = path.posix.normalize("../../folder/subfolder")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "..")
		assert.eq(result.parts[3], "folder")
		assert.eq(result.parts[4], "subfolder")
	end)

	suite:case("normalizeFolderThenMultipleParents", function(assert)
		local result = path.posix.normalize("folder/subfolder/../../other")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "other")
	end)
end)

test.suite("PathPosixJoinSuite", function(suite)
	suite:case("joinAbsoluteAndRelative", function(assert)
		local result = path.posix.join("/home/user", "documents", "file.txt")
		assert.that(result.absolute)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("joinRelativePaths", function(assert)
		local result = path.posix.join("documents", "subfolder", "file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "documents")
		assert.eq(result.parts[2], "subfolder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("joinEmptyParts", function(assert)
		local result = path.posix.join("folder", "", "file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "folder")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("joinNoArguments", function(assert)
		local result = path.posix.join()
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("joinSingleArgument", function(assert)
		local result = path.posix.join("/home/user")
		assert.that(result.absolute)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
	end)

	suite:case("joinPathobjAndString", function(assert)
		local pathobj: posix.Path = setmetatable({
			parts = { "home", "user" },
			absolute = true,
		}, posix.pathmt)
		local result = path.posix.join(pathobj, "documents/file.txt")
		assert.that(result.absolute)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
		assert.eq(#pathobj.parts, 2) -- original pathobj should be unchanged
		assert.eq(pathobj.parts[1], "home")
		assert.eq(pathobj.parts[2], "user")
		assert.that(pathobj.absolute)
	end)

	suite:case("joinErrorOnAbsoluteAddend", function(assert)
		local success, _ = pcall(function()
			return path.posix.join("/home/user", "/absolute/path")
		end)
		assert.eq(success, false)
	end)
end)

test.suite("PathPosixResolveSuite", function(suite)
	suite:case("resolveAbsolutePath", function(assert)
		local result = path.posix.resolve("/home/user/documents/file.txt")
		assert.that(result.absolute)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("resolveRelativePathFromCwd", function(assert)
		-- This test assumes we're in some working directory
		local result = path.posix.resolve("documents/file.txt")
		-- Absolute Windows paths will be parsed as relative posix paths because they don't start with /
		assert.neq(result.absolute, system.win32)
		-- The exact parts will depend on the current working directory
		-- But we can check that it ends with our relative path
		local endIndex = #result.parts
		assert.eq(result.parts[endIndex - 1], "documents")
		assert.eq(result.parts[endIndex], "file.txt")
	end)

	suite:case("resolveMultiplePaths", function(assert)
		local result = path.posix.resolve("/home", "user", "../admin", "documents")
		assert.that(result.absolute)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "documents")
	end)

	suite:case("resolveWithAbsoluteInMiddle", function(assert)
		local result = path.posix.resolve("relative", "/absolute/path", "more")
		assert.that(result.absolute)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "absolute")
		assert.eq(result.parts[2], "path")
		assert.eq(result.parts[3], "more")
	end)

	suite:case("resolveNoArguments", function(assert)
		-- Should return normalized current working directory
		local result = path.posix.resolve()
		-- Absolute Windows paths will be parsed as relative posix paths because they don't start with /
		assert.neq(result.absolute, system.win32)
		-- Can't test exact parts since cwd varies
	end)

	suite:case("resolveEmptyStrings", function(assert)
		local result = path.posix.resolve("", "", "/home/user")
		assert.that(result.absolute)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
	end)

	suite:case("resolveWithDotSegments", function(assert)
		local result = path.posix.resolve("/home/user", "../admin/./documents")
		assert.that(result.absolute)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "documents")
	end)
end)

test.suite("PathPosixToStringSuite", function(suite)
	suite:case("toStringPosixAbsolutePath", function(assert)
		local filePath = "/home/user/documents/file.txt"
		local pathobj: posix.Path = posix.parse(filePath)
		local result = tostring(pathobj)
		assert.eq(result, filePath)
	end)

	suite:case("toStringPosixRelativePath", function(assert)
		local filePath = "documents/file.txt"
		local pathobj: posix.Path = posix.parse(filePath)
		local result = tostring(pathobj)
		assert.eq(result, filePath)
	end)
end)

test.suite("PathPosixRelativeSuite", function(suite)
	suite:case("relativeSamePath", function(assert)
		local from = posix.parse("/home/user/documents")
		local to = posix.parse("/home/user/documents")
		local result = path.posix.relative(from, to)
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("relativeSubdirectory", function(assert)
		local from = posix.parse("/home/user")
		local to = posix.parse("/home/user/documents/file.txt")
		local result = path.posix.relative(from, to)
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("relativeParentDirectory", function(assert)
		local from = posix.parse("/home/user/documents")
		local to = posix.parse("/home/user/file.txt")
		local result = path.posix.relative(from, to)
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("relativeDifferentAbsoluteValues", function(assert)
		local from = posix.parse("/home/user/documents")
		local to = posix.parse("home/user/file.txt")
		assert.throwsWith("Cannot compute relative path between absolute and relative paths", function()
			path.posix.relative(from, to)
		end)
	end)
end)
