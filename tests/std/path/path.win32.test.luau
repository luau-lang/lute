local system = require("@std/system")
local test = require("@std/test")
local process = require("@std/process")

local path = require("@std/path")
local win32 = require("@std/path/win32")

test.suite("PathWin32ParseSuite", function(suite)
	suite:case("parseWindowsAbsolutePath", function(assert)
		local result: win32.path = path.win32.parse("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parseWindowsUncPath", function(assert)
		local result: win32.path = path.win32.parse("\\\\server\\share\\folder\\file.txt")
		assert.eq(result.kind, "unc")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "folder")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parseEmptyString", function(assert)
		local result: win32.path = path.win32.parse("")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 0)
	end)

	suite:case("parseSingleFile", function(assert)
		local result: win32.path = path.win32.parse("file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "file.txt")
	end)

	suite:case("parsePathobjReturnsSame", function(assert)
		local originalPath: win32.path = setmetatable({
			parts = { "folder", "file.txt" },
			kind = "relative",
			drive = nil :: string?,
		}, win32.pathmt)
		local result = path.win32.parse(originalPath)
		assert.eq(result, originalPath)
	end)

	suite:case("parseMixedSeparators", function(assert)
		local result: win32.path = path.win32.parse("/home/user\\documents/file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parseWindowsRelativeWithDrive", function(assert)
		local result: win32.path = path.win32.parse("C:Documents\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "file.txt")
	end)
end)

test.suite("PathWin32BasenameSuite", function(suite)
	suite:case("basenameWindowsAbsolutePath", function(assert)
		local result = path.win32.basename("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basenameWindowsUncPath", function(assert)
		local result = path.win32.basename("\\\\server\\share\\folder\\file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basenameSingleFile", function(assert)
		local result = path.win32.basename("file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basenameDirectoryNoExtension", function(assert)
		local result = path.win32.basename("C:\\Users\\username\\Documents")
		assert.eq(result, "Documents")
	end)

	suite:case("basenameEmptyPath", function(assert)
		local result = path.win32.basename("")
		assert.eq(result, nil)
	end)

	suite:case("basenameRootPath", function(assert)
		local result = path.win32.basename("C:\\")
		assert.eq(result, nil)
	end)

	suite:case("basenamePathobj", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "folder", "subfolder", "file.txt" },
			kind = "relative",
			drive = nil :: string?,
		}, win32.pathmt)
		local result = path.win32.basename(pathobj)
		assert.eq(result, "file.txt")
	end)

	suite:case("basenameMixedSeparators", function(assert)
		local result = path.win32.basename("/home/user\\documents/file.txt")
		assert.eq(result, "file.txt")
	end)
end)

test.suite("PathWin32FormatSuite", function(suite)
	suite:case("formatWindowsAbsolutePath", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "Users", "username", "Documents", "file.txt" },
			kind = "absolute",
			drive = "C" :: string?,
		}, win32.pathmt)
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:\\Users\\username\\Documents\\file.txt")
	end)

	suite:case("formatWindowsRelativeWithDrive", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "Documents", "file.txt" },
			kind = "relative",
			drive = "C" :: string?,
		}, win32.pathmt)
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:Documents\\file.txt")
	end)

	suite:case("formatWindowsUncPath", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "server", "share", "folder", "file.txt" },
			kind = "unc",
			drive = nil :: string?,
		}, win32.pathmt)
		local result = path.win32.format(pathobj)
		assert.eq(result, "\\\\server\\share\\folder\\file.txt")
	end)

	suite:case("formatEmptyRelativePath", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = {},
			kind = "relative",
			drive = nil :: string?,
		}, win32.pathmt)
		local result = path.win32.format(pathobj)
		assert.eq(result, ".")
	end)

	suite:case("formatEmptyRelativePathWithDrive", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = {},
			kind = "relative",
			drive = "C" :: string?,
		}, win32.pathmt)
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:")
	end)

	suite:case("formatRootPathWithDrive", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = {},
			kind = "absolute",
			drive = "C" :: string?,
		}, win32.pathmt)
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:\\")
	end)

	suite:case("formatStringReturnsSame", function(assert)
		local result = path.win32.format("/home/user/file.txt")
		assert.eq(result, "/home/user/file.txt")
	end)
end)

test.suite("PathWin32DirnameSuite", function(suite)
	suite:case("dirnameWindowsAbsolutePath", function(assert)
		local result = path.win32.dirname("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result, "C:\\Users\\username\\Documents")
	end)

	suite:case("dirnameWindowsUncPath", function(assert)
		local result = path.win32.dirname("\\\\server\\share\\folder\\file.txt")
		assert.eq(result, "\\\\server\\share\\folder")
	end)

	suite:case("dirnameSingleFile", function(assert)
		local result = path.win32.dirname("file.txt")
		assert.eq(result, ".")
	end)

	suite:case("dirnameEmptyPath", function(assert)
		local result = path.win32.dirname("")
		assert.eq(result, ".")
	end)

	suite:case("dirnameWindowsRoot", function(assert)
		local result = path.win32.dirname("C:\\")
		assert.eq(result, "C:\\")
	end)

	suite:case("dirnamePathobj", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "folder", "subfolder", "file.txt" },
			kind = "relative",
			drive = nil :: string?,
		}, win32.pathmt)
		local result = path.win32.dirname(pathobj)
		assert.eq(result, "folder\\subfolder")
	end)

	suite:case("dirnameWindowsRelativeWithDrive", function(assert)
		local result = path.win32.dirname("C:Documents\\file.txt")
		assert.eq(result, "C:Documents")
	end)
end)

test.suite("PathWin32ExtnameSuite", function(suite)
	suite:case("extnameSimpleExtension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\file.txt")
		assert.eq(result, ".txt")
	end)

	suite:case("extnameMultipleDots", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\archive.tar.gz")
		assert.eq(result, ".gz")
	end)

	suite:case("extnameNoExtension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\README")
		assert.eq(result, "")
	end)

	suite:case("extnameHiddenFileWithExtension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\.bashrc")
		assert.eq(result, "")
	end)

	suite:case("extnameHiddenFileWithRealExtension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\.config.json")
		assert.eq(result, ".json")
	end)

	suite:case("extnameWindowsPath", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\document.docx")
		assert.eq(result, ".docx")
	end)

	suite:case("extnameDirectoryPath", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\documents")
		assert.eq(result, "")
	end)

	suite:case("extnameEmptyPath", function(assert)
		local result = path.win32.extname("")
		assert.eq(result, "")
	end)

	suite:case("extnameRootPath", function(assert)
		local result = path.win32.extname("C:\\")
		assert.eq(result, "")
	end)

	suite:case("extnamePathobj", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "folder", "file.pdf" },
			kind = "relative",
			drive = nil :: string?,
		}, win32.pathmt)
		local result = path.win32.extname(pathobj)
		assert.eq(result, ".pdf")
	end)

	suite:case("extnameDotOnly", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\file.")
		assert.eq(result, ".")
	end)

	suite:case("extnameFilenameIsDot", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\.")
		assert.eq(result, "")
	end)

	suite:case("extnameFilenameIsDotdot", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\..")
		assert.eq(result, "")
	end)
end)

test.suite("PathWin32GetDriveSuite", function(suite)
	suite:case("getdriveAbsolutePathString", function(assert)
		local result = path.win32.drive("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 0)
	end)

	suite:case("getdriveRelativePathWithDrive", function(assert)
		local result = path.win32.drive("D:Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "D")
		assert.eq(#result.parts, 0)
	end)

	suite:case("getdrivePathObject", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "Users", "username", "Documents" },
			kind = "absolute",
			drive = "E" :: string?,
		}, win32.pathmt)
		local result = path.win32.drive(pathobj)
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "E")
		assert.eq(#result.parts, 0)
	end)

	suite:case("getdriveRootPath", function(assert)
		local result = path.win32.drive("F:\\")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "F")
		assert.eq(#result.parts, 0)
	end)

	suite:case("getdriveErrorOnEmptyPath", function(assert)
		assert.errors(function()
			path.win32.drive("")
		end)
	end)
end)

test.suite("PathWin32IsAbsoluteSuite", function(suite)
	suite:case("isAbsoluteWindowsAbsolutePath", function(assert)
		local result = path.win32.isabsolute("C:\\Users\\username\\Documents\\file.txt")
		assert.truthy(result)
	end)

	suite:case("isAbsoluteWindowsRelativePath", function(assert)
		local result = path.win32.isabsolute("Documents\\file.txt")
		assert.eq(result, false)
	end)

	suite:case("isAbsoluteWindowsRelativeWithDrive", function(assert)
		local result = path.win32.isabsolute("C:Documents\\file.txt")
		assert.eq(result, false)
	end)

	suite:case("isAbsoluteWindowsUncPath", function(assert)
		local result = path.win32.isabsolute("\\\\server\\share\\folder\\file.txt")
		assert.truthy(result)
	end)

	suite:case("isAbsoluteRootPath", function(assert)
		local result = path.win32.isabsolute("C:\\")
		assert.truthy(result)
	end)

	suite:case("isAbsoluteEmptyPath", function(assert)
		local result = path.win32.isabsolute("")
		assert.eq(result, false)
	end)

	suite:case("isAbsolutePathobjAbsolute", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "home", "user", "file.txt" },
			kind = "absolute",
			drive = "C" :: string?,
		}, win32.pathmt)
		local result = path.win32.isabsolute(pathobj)
		assert.truthy(result)
	end)

	suite:case("isAbsolutePathobjRelative", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "folder", "file.txt" },
			kind = "relative",
			drive = nil :: string?,
		}, win32.pathmt)
		local result = path.win32.isabsolute(pathobj)
		assert.eq(result, false)
	end)
end)

test.suite("PathWin32NormalizeSuite", function(suite)
	suite:case("normalizeRemovesCurrentDirectory", function(assert)
		local result = path.win32.normalize("C:\\Users\\.\\username\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("normalizeResolvesParentDirectory", function(assert)
		local result = path.win32.normalize("C:\\Users\\username\\..\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "Documents")
	end)

	suite:case("normalizeMultipleDots", function(assert)
		local result = path.win32.normalize("C:\\Users\\username\\.\\Documents\\..\\files\\.\\")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "files")
	end)

	suite:case("normalizeRelativePath", function(assert)
		local result = path.win32.normalize("Documents\\.\\subfolder\\..\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("normalizeRemovesEmptySegments", function(assert)
		local result = path.win32.normalize("C:\\Users\\\\username\\\\\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("normalizeParentBeyondRoot", function(assert)
		local result = path.win32.normalize("C:\\Users\\..\\..\\")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalizeUncPath", function(assert)
		local result = path.win32.normalize("\\\\server\\share\\.\\folder\\..\\files")
		assert.eq(result.kind, "unc")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "files")
	end)

	suite:case("normalizeRelativeWithDrive", function(assert)
		local result = path.win32.normalize("C:Documents\\.\\subfolder\\..\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("normalizeParentDirectoryOnly", function(assert)
		local result = path.win32.normalize("..")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "..")
	end)

	suite:case("normalizeMultipleParentDirectories", function(assert)
		local result = path.win32.normalize("..\\..\\..")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "..")
		assert.eq(result.parts[3], "..")
	end)

	suite:case("normalizeParentThenFolder", function(assert)
		local result = path.win32.normalize("..\\folder\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "folder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("normalizeFolderThenMultipleParents", function(assert)
		local result = path.win32.normalize("folder\\subfolder\\..\\..\\other")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "other")
	end)

	suite:case("normalizePathobj", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "Users", ".", "username", "..", "Documents" },
			kind = "absolute",
			drive = "C" :: string?,
		}, win32.pathmt)
		local result = path.win32.normalize(pathobj)
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "Documents")
	end)

	suite:case("normalizeRelativeWithDriveAndParent", function(assert)
		local result = path.win32.normalize("C:..\\folder\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "folder")
		assert.eq(result.parts[3], "file.txt")
	end)
end)

test.suite("PathWin32JoinSuite", function(suite)
	suite:case("joinAbsoluteAndRelative", function(assert)
		local result = path.win32.join("C:\\Users\\username", "Documents", "file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("joinRelativePaths", function(assert)
		local result = path.win32.join("Documents", "subfolder", "file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "subfolder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("joinDriveRelativePaths", function(assert)
		local result = path.win32.join("C:Documents", "subfolder", "file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "subfolder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("joinUncAndRelative", function(assert)
		local result = path.win32.join("\\\\server\\share", "folder", "file.txt")
		assert.eq(result.kind, "unc")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "folder")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("joinNoArguments", function(assert)
		local result = path.win32.join()
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 0)
	end)

	suite:case("joinPathobjAndString", function(assert)
		local pathobj: win32.path = setmetatable({
			parts = { "Users", "username" },
			kind = "absolute",
			drive = "C" :: string?,
		}, win32.pathmt)
		local result = path.win32.join(pathobj, "Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
		assert.eq(#pathobj.parts, 2) -- original pathobj should be unchanged
		assert.eq(pathobj.parts[1], "Users")
		assert.eq(pathobj.parts[2], "username")
		assert.eq(pathobj.kind, "absolute")
		assert.eq(pathobj.drive, "C")
	end)

	suite:case("joinErrorOnAbsoluteAddend", function(assert)
		local success, _ = pcall(function()
			return path.win32.join("C:\\Users", "D:\\absolute\\path")
		end)
		assert.eq(success, false)
	end)

	suite:case("joinErrorOnUncAddend", function(assert)
		local success, _ = pcall(function()
			return path.win32.join("C:\\Users", "\\\\server\\share")
		end)
		assert.eq(success, false)
	end)

	suite:case("joinErrorOnIncompatibleDrives", function(assert)
		local success, _ = pcall(function()
			return path.win32.join("C:Documents", "D:other")
		end)
		assert.eq(success, false)
	end)

	suite:case("joinCompatibleDrives", function(assert)
		local result = path.win32.join("C:Documents", "C:subfolder")
		assert.eq(result.kind, "relative")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "subfolder")
	end)
end)

test.suite("PathWin32ResolveSuite", function(suite)
	suite:case("resolveAbsolutePath", function(assert)
		local result = path.win32.resolve("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("resolveRelativePathFromCwd", function(assert)
		-- This test assumes we're in some working directory
		local result = path.win32.resolve("Documents\\file.txt")
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		assert.eq(result.kind, if system.win32 then "absolute" else "relative")
		-- The exact parts will depend on the current working directory
		-- But we can check that it ends with our relative path
		-- In an ideal world, we'd mock `process.cwd`
		local endIndex = #result.parts
		assert.eq(result.parts[endIndex - 1], "Documents")
		assert.eq(result.parts[endIndex], "file.txt")
	end)

	suite:case("resolveMultiplePaths", function(assert)
		local result = path.win32.resolve("C:\\Users", "username", "..\\admin", "Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("resolveWithAbsoluteInMiddle", function(assert)
		local result = path.win32.resolve("relative", "D:\\absolute\\path", "more")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "D")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "absolute")
		assert.eq(result.parts[2], "path")
		assert.eq(result.parts[3], "more")
	end)

	suite:case("resolveUncPath", function(assert)
		local result = path.win32.resolve("\\\\server\\share\\folder")
		assert.eq(result.kind, "unc")
		assert.eq(result.drive, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "folder")
	end)

	suite:case("resolveNoArguments", function(assert)
		-- Should return normalized current working directory
		local result = path.win32.resolve()
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		assert.eq(result.kind, if system.win32 then "absolute" else "relative")
		-- Can't test exact parts since cwd varies
	end)

	suite:case("resolveDriveRelativePath", function(assert)
		-- Get the drive letter from the current working directory
		local cwdPath = path.win32.parse(process.cwd() :: win32.pathlike)
		local drive = if system.win32 then path.win32.drive(cwdPath).drive :: string else "C"

		local testPath = drive .. ":Documents\\file.txt"
		local result = path.win32.resolve(testPath)
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		assert.eq(result.kind, if system.win32 then "absolute" else "relative")
		assert.eq(result.drive, drive)
		-- The exact parts depend on cwd, but should be absolute
		local endIndex = #result.parts
		assert.eq(result.parts[endIndex - 1], "Documents")
		assert.eq(result.parts[endIndex], "file.txt")
	end)

	suite:case("resolveWithDotSegments", function(assert)
		local result = path.win32.resolve("C:\\Users\\username", "..\\admin\\.\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("resolveEmptyStrings", function(assert)
		local result = path.win32.resolve("", "", "C:\\Users\\username")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
	end)
end)

test.suite("PathWin32ToStringSuite", function(suite)
	suite:case("toStringWindowsAbsolutePath", function(assert)
		local filePath = "C:\\Users\\username\\Documents\\file.txt"
		local pathObj: win32.path = win32.parse(filePath)
		local result = tostring(pathObj)
		assert.eq(result, filePath)
	end)

	suite:case("toStringWindowsRelativePath", function(assert)
		local filePath = "C:\\Users\\username\\Documents\\file.txt"
		local pathObj: win32.path = path.win32.parse(filePath)
		local result = tostring(pathObj)
		assert.eq(result, filePath)
	end)
end)

test.suite("PathWin32RelativeSuite", function(suite)
	suite:case("relativeSamePath", function(assert)
		local from = win32.parse("C:\\Users\\username\\Documents")
		local to = win32.parse("C:\\Users\\username\\Documents")
		local result = path.win32.relative(from, to)
		assert.eq(result.kind, "relative")
		assert.eq(#result.parts, 0)
		assert.eq(result.drive, nil)
	end)

	suite:case("relativeSubdirectory", function(assert)
		local from = win32.parse("C:\\Users\\username")
		local to = win32.parse("C:\\Users\\username\\Documents\\file.txt")
		local result = path.win32.relative(from, to)
		assert.eq(result.kind, "relative")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "file.txt")
		assert.eq(result.drive, nil)
	end)

	suite:case("relativeParentDirectory", function(assert)
		local from = win32.parse("C:\\Users\\username\\Documents")
		local to = win32.parse("C:\\Users\\username\\file.txt")
		local result = path.win32.relative(from, to)
		assert.eq(result.kind, "relative")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "file.txt")
		assert.eq(result.drive, nil)
	end)

	suite:case("relativeDifferentKinds", function(assert)
		local from = win32.parse("C:\\Users\\username\\Documents")
		local to = win32.parse("Documents\\file.txt")
		assert.erroreq(function()
			path.win32.relative(from, to)
		end, "Cannot compute relative path between different kinds of paths")
	end)

	suite:case("relativeDifferentDrives", function(assert)
		local from = win32.parse("C:\\Users\\username")
		local to = win32.parse("D:\\Documents\\file.txt")
		assert.erroreq(function()
			path.win32.relative(from, to)
		end, "Cannot compute relative path between different drives")
	end)

	suite:case("relativeUncPaths", function(assert)
		local from = win32.parse("\\\\server\\share\\folder1")
		local to = win32.parse("\\\\server\\share\\folder2\\file.txt")
		local result = path.win32.relative(from, to)
		assert.eq(result.kind, "relative")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "folder2")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("relativeWithDriveLetterSameDrive", function(assert)
		local from = win32.parse("C:Documents")
		local to = win32.parse("C:Documents\\subfolder\\file.txt")
		local result = path.win32.relative(from, to)
		assert.eq(result.kind, "relative")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "subfolder")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("parseWindowsAbsolutePathWithForwardSlashes", function(assert)
		local result: win32.path = path.win32.parse("C:/Users/username/Documents/file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.drive, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
	end)
end)
