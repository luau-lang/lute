local system = require("@std/system")
local test = require("@std/test")

local path = require("@std/path")
local win32 = require("@std/path/win32")

test.suite("PathWin32ParseSuite", function(suite)
	suite:case("parse_windows_absolute_path", function(assert)
		local result: win32.path = path.win32.parse("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parse_windows_unc_path", function(assert)
		local result: win32.path = path.win32.parse("\\\\server\\share\\folder\\file.txt")
		assert.eq(result.kind, "unc")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "folder")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parse_empty_string", function(assert)
		local result: win32.path = path.win32.parse("")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 0)
	end)

	suite:case("parse_single_file", function(assert)
		local result: win32.path = path.win32.parse("file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "file.txt")
	end)

	suite:case("parse_pathobj_returns_same", function(assert)
		local originalPath: win32.path = {
			parts = { "folder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.parse(originalPath)
		assert.eq(result, originalPath)
	end)

	suite:case("parse_mixed_separators", function(assert)
		local result: win32.path = path.win32.parse("/home/user\\documents/file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parse_windows_relative_with_drive", function(assert)
		local result: win32.path = path.win32.parse("C:Documents\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "file.txt")
	end)
end)

test.suite("PathWin32BasenameSuite", function(suite)
	suite:case("basename_windows_absolute_path", function(assert)
		local result = path.win32.basename("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basename_windows_unc_path", function(assert)
		local result = path.win32.basename("\\\\server\\share\\folder\\file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basename_single_file", function(assert)
		local result = path.win32.basename("file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basename_directory_no_extension", function(assert)
		local result = path.win32.basename("C:\\Users\\username\\Documents")
		assert.eq(result, "Documents")
	end)

	suite:case("basename_empty_path", function(assert)
		local result = path.win32.basename("")
		assert.eq(result, nil)
	end)

	suite:case("basename_root_path", function(assert)
		local result = path.win32.basename("C:\\")
		assert.eq(result, nil)
	end)

	suite:case("basename_pathobj", function(assert)
		local pathobj: win32.path = {
			parts = { "folder", "subfolder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.basename(pathobj)
		assert.eq(result, "file.txt")
	end)

	suite:case("basename_mixed_separators", function(assert)
		local result = path.win32.basename("/home/user\\documents/file.txt")
		assert.eq(result, "file.txt")
	end)
end)

test.suite("PathWin32FormatSuite", function(suite)
	suite:case("format_windows_absolute_path", function(assert)
		local pathobj: win32.path = {
			parts = { "Users", "username", "Documents", "file.txt" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:\\Users\\username\\Documents\\file.txt")
	end)

	suite:case("format_windows_relative_with_drive", function(assert)
		local pathobj: win32.path = {
			parts = { "Documents", "file.txt" },
			kind = "relative",
			driveLetter = "C",
		}
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:Documents\\file.txt")
	end)

	suite:case("format_windows_unc_path", function(assert)
		local pathobj: win32.path = {
			parts = { "server", "share", "folder", "file.txt" },
			kind = "unc",
			driveLetter = nil,
		}
		local result = path.win32.format(pathobj)
		assert.eq(result, "\\\\server\\share\\folder\\file.txt")
	end)

	suite:case("format_empty_relative_path", function(assert)
		local pathobj: win32.path = {
			parts = {},
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.format(pathobj)
		assert.eq(result, ".")
	end)

	suite:case("format_empty_relative_path_with_drive", function(assert)
		local pathobj: win32.path = {
			parts = {},
			kind = "relative",
			driveLetter = "C",
		}
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:")
	end)

	suite:case("format_root_path_with_drive", function(assert)
		local pathobj: win32.path = {
			parts = {},
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.format(pathobj)
		assert.eq(result, "C:\\")
	end)

	suite:case("format_string_returns_same", function(assert)
		local result = path.win32.format("/home/user/file.txt")
		assert.eq(result, "/home/user/file.txt")
	end)
end)

test.suite("PathWin32DirnameSuite", function(suite)
	suite:case("dirname_windows_absolute_path", function(assert)
		local result = path.win32.dirname("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result, "C:\\Users\\username\\Documents")
	end)

	suite:case("dirname_windows_unc_path", function(assert)
		local result = path.win32.dirname("\\\\server\\share\\folder\\file.txt")
		assert.eq(result, "\\\\server\\share\\folder")
	end)

	suite:case("dirname_single_file", function(assert)
		local result = path.win32.dirname("file.txt")
		assert.eq(result, ".")
	end)

	suite:case("dirname_empty_path", function(assert)
		local result = path.win32.dirname("")
		assert.eq(result, ".")
	end)

	suite:case("dirname_windows_root", function(assert)
		local result = path.win32.dirname("C:\\")
		assert.eq(result, "C:\\")
	end)

	suite:case("dirname_pathobj", function(assert)
		local pathobj: win32.path = {
			parts = { "folder", "subfolder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.dirname(pathobj)
		assert.eq(result, "folder\\subfolder")
	end)

	suite:case("dirname_windows_relative_with_drive", function(assert)
		local result = path.win32.dirname("C:Documents\\file.txt")
		assert.eq(result, "C:Documents")
	end)
end)

test.suite("PathWin32ExtnameSuite", function(suite)
	suite:case("extname_simple_extension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\file.txt")
		assert.eq(result, ".txt")
	end)

	suite:case("extname_multiple_dots", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\archive.tar.gz")
		assert.eq(result, ".gz")
	end)

	suite:case("extname_no_extension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\README")
		assert.eq(result, "")
	end)

	suite:case("extname_hidden_file_with_extension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\.bashrc")
		assert.eq(result, "")
	end)

	suite:case("extname_hidden_file_with_real_extension", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\.config.json")
		assert.eq(result, ".json")
	end)

	suite:case("extname_windows_path", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\document.docx")
		assert.eq(result, ".docx")
	end)

	suite:case("extname_directory_path", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\documents")
		assert.eq(result, "")
	end)

	suite:case("extname_empty_path", function(assert)
		local result = path.win32.extname("")
		assert.eq(result, "")
	end)

	suite:case("extname_root_path", function(assert)
		local result = path.win32.extname("C:\\")
		assert.eq(result, "")
	end)

	suite:case("extname_pathobj", function(assert)
		local pathobj: win32.path = {
			parts = { "folder", "file.pdf" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.extname(pathobj)
		assert.eq(result, ".pdf")
	end)

	suite:case("extname_dot_only", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\file.")
		assert.eq(result, ".")
	end)

	suite:case("extname_filename_is_dot", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\.")
		assert.eq(result, "")
	end)

	suite:case("extname_filename_is_dotdot", function(assert)
		local result = path.win32.extname("C:\\Users\\username\\..")
		assert.eq(result, "")
	end)
end)

test.suite("PathWin32IsAbsoluteSuite", function(suite)
	suite:case("isAbsolute_windows_absolute_path", function(assert)
		local result = path.win32.isabsolute("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result, true)
	end)

	suite:case("isAbsolute_windows_relative_path", function(assert)
		local result = path.win32.isabsolute("Documents\\file.txt")
		assert.eq(result, false)
	end)

	suite:case("isAbsolute_windows_relative_with_drive", function(assert)
		local result = path.win32.isabsolute("C:Documents\\file.txt")
		assert.eq(result, false)
	end)

	suite:case("isAbsolute_windows_unc_path", function(assert)
		local result = path.win32.isabsolute("\\\\server\\share\\folder\\file.txt")
		assert.eq(result, true)
	end)

	suite:case("isAbsolute_root_path", function(assert)
		local result = path.win32.isabsolute("C:\\")
		assert.eq(result, true)
	end)

	suite:case("isAbsolute_empty_path", function(assert)
		local result = path.win32.isabsolute("")
		assert.eq(result, false)
	end)

	suite:case("isAbsolute_pathobj_absolute", function(assert)
		local pathobj: win32.path = {
			parts = { "home", "user", "file.txt" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.isabsolute(pathobj)
		assert.eq(result, true)
	end)

	suite:case("isAbsolute_pathobj_relative", function(assert)
		local pathobj: win32.path = {
			parts = { "folder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.isabsolute(pathobj)
		assert.eq(result, false)
	end)
end)

test.suite("PathWin32NormalizeSuite", function(suite)
	suite:case("normalize_removes_current_directory", function(assert)
		local result = path.win32.normalize("C:\\Users\\.\\username\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("normalize_resolves_parent_directory", function(assert)
		local result = path.win32.normalize("C:\\Users\\username\\..\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "Documents")
	end)

	suite:case("normalize_multiple_dots", function(assert)
		local result = path.win32.normalize("C:\\Users\\username\\.\\Documents\\..\\files\\.\\")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "files")
	end)

	suite:case("normalize_relative_path", function(assert)
		local result = path.win32.normalize("Documents\\.\\subfolder\\..\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("normalize_removes_empty_segments", function(assert)
		local result = path.win32.normalize("C:\\Users\\\\username\\\\\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("normalize_parent_beyond_root", function(assert)
		local result = path.win32.normalize("C:\\Users\\..\\..\\")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalize_unc_path", function(assert)
		local result = path.win32.normalize("\\\\server\\share\\.\\folder\\..\\files")
		assert.eq(result.kind, "unc")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "files")
	end)

	suite:case("normalize_relative_with_drive", function(assert)
		local result = path.win32.normalize("C:Documents\\.\\subfolder\\..\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("normalize_parent_directory_only", function(assert)
		local result = path.win32.normalize("..")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "..")
	end)

	suite:case("normalize_multiple_parent_directories", function(assert)
		local result = path.win32.normalize("..\\..\\..")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "..")
		assert.eq(result.parts[3], "..")
	end)

	suite:case("normalize_parent_then_folder", function(assert)
		local result = path.win32.normalize("..\\folder\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "folder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("normalize_folder_then_multiple_parents", function(assert)
		local result = path.win32.normalize("folder\\subfolder\\..\\..\\other")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "other")
	end)

	suite:case("normalize_pathobj", function(assert)
		local pathobj: win32.path = {
			parts = { "Users", ".", "username", "..", "Documents" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.normalize(pathobj)
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "Documents")
	end)

	suite:case("normalize_relative_with_drive_and_parent", function(assert)
		local result = path.win32.normalize("C:..\\folder\\file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "folder")
		assert.eq(result.parts[3], "file.txt")
	end)
end)

test.suite("PathWin32JoinSuite", function(suite)
	suite:case("join_absolute_and_relative", function(assert)
		local result = path.win32.join("C:\\Users\\username", "Documents", "file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("join_relative_paths", function(assert)
		local result = path.win32.join("Documents", "subfolder", "file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "subfolder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("join_drive_relative_paths", function(assert)
		local result = path.win32.join("C:Documents", "subfolder", "file.txt")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "subfolder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("join_unc_and_relative", function(assert)
		local result = path.win32.join("\\\\server\\share", "folder", "file.txt")
		assert.eq(result.kind, "unc")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "folder")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("join_no_arguments", function(assert)
		local result = path.win32.join()
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 0)
	end)

	suite:case("join_pathobj_and_string", function(assert)
		local pathobj: win32.path = {
			parts = { "Users", "username" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.join(pathobj, "Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
		assert.eq(#pathobj.parts, 2) -- original pathobj should be unchanged
		assert.eq(pathobj.parts[1], "Users")
		assert.eq(pathobj.parts[2], "username")
		assert.eq(pathobj.kind, "absolute")
		assert.eq(pathobj.driveLetter, "C")
	end)

	suite:case("join_error_on_absolute_addend", function(assert)
		local success, _ = pcall(function()
			return path.win32.join("C:\\Users", "D:\\absolute\\path")
		end)
		assert.eq(success, false)
	end)

	suite:case("join_error_on_unc_addend", function(assert)
		local success, _ = pcall(function()
			return path.win32.join("C:\\Users", "\\\\server\\share")
		end)
		assert.eq(success, false)
	end)

	suite:case("join_error_on_incompatible_drives", function(assert)
		local success, _ = pcall(function()
			return path.win32.join("C:Documents", "D:other")
		end)
		assert.eq(success, false)
	end)

	suite:case("join_compatible_drives", function(assert)
		local result = path.win32.join("C:Documents", "C:subfolder")
		assert.eq(result.kind, "relative")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Documents")
		assert.eq(result.parts[2], "subfolder")
	end)
end)

test.suite("PathWin32ResolveSuite", function(suite)
	suite:case("resolve_absolute_path", function(assert)
		local result = path.win32.resolve("C:\\Users\\username\\Documents\\file.txt")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
		assert.eq(result.parts[3], "Documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("resolve_relative_path_from_cwd", function(assert)
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

	suite:case("resolve_multiple_paths", function(assert)
		local result = path.win32.resolve("C:\\Users", "username", "..\\admin", "Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("resolve_with_absolute_in_middle", function(assert)
		local result = path.win32.resolve("relative", "D:\\absolute\\path", "more")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "D")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "absolute")
		assert.eq(result.parts[2], "path")
		assert.eq(result.parts[3], "more")
	end)

	suite:case("resolve_unc_path", function(assert)
		local result = path.win32.resolve("\\\\server\\share\\folder")
		assert.eq(result.kind, "unc")
		assert.eq(result.driveLetter, nil)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "server")
		assert.eq(result.parts[2], "share")
		assert.eq(result.parts[3], "folder")
	end)

	suite:case("resolve_no_arguments", function(assert)
		-- Should return normalized current working directory
		local result = path.win32.resolve()
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		assert.eq(result.kind, if system.win32 then "absolute" else "relative")
		-- Can't test exact parts since cwd varies
	end)

	suite:case("resolve_drive_relative_path", function(assert)
		local result = path.win32.resolve("C:Documents\\file.txt")
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		assert.eq(result.kind, if system.win32 then "absolute" else "relative")
		assert.eq(result.driveLetter, "C")
		-- The exact parts depend on cwd, but should be absolute
		local endIndex = #result.parts
		assert.eq(result.parts[endIndex - 1], "Documents")
		assert.eq(result.parts[endIndex], "file.txt")
	end)

	suite:case("resolve_with_dot_segments", function(assert)
		local result = path.win32.resolve("C:\\Users\\username", "..\\admin\\.\\Documents")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "Documents")
	end)

	suite:case("resolve_empty_strings", function(assert)
		local result = path.win32.resolve("", "", "C:\\Users\\username")
		assert.eq(result.kind, "absolute")
		assert.eq(result.driveLetter, "C")
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "Users")
		assert.eq(result.parts[2], "username")
	end)
end)

test.run()
