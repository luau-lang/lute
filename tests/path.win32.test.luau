local system = require("@std/system")
local test = require("@std/test")

local path = require("@std/path")
local win32 = require("@std/path/win32")

test.suite("PathWin32ParseSuite", function()
	test.case("parse_windows_absolute_path", function()
		local result: win32.WindowsPath = path.win32.parse("C:\\Users\\username\\Documents\\file.txt")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
		test.assert.eq(result.parts[3], "Documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("parse_windows_unc_path", function()
		local result: win32.WindowsPath = path.win32.parse("\\\\server\\share\\folder\\file.txt")
		test.assert.eq(result.kind, "unc")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "server")
		test.assert.eq(result.parts[2], "share")
		test.assert.eq(result.parts[3], "folder")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("parse_empty_string", function()
		local result: win32.WindowsPath = path.win32.parse("")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("parse_single_file", function()
		local result: win32.WindowsPath = path.win32.parse("file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 1)
		test.assert.eq(result.parts[1], "file.txt")
	end)

	test.case("parse_pathobj_returns_same", function()
		local originalPath: win32.WindowsPath = {
			parts = { "folder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.parse(originalPath)
		test.assert.eq(result, originalPath)
	end)

	test.case("parse_mixed_separators", function()
		local result: win32.WindowsPath = path.win32.parse("/home/user\\documents/file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("parse_windows_relative_with_drive", function()
		local result: win32.WindowsPath = path.win32.parse("C:Documents\\file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "Documents")
		test.assert.eq(result.parts[2], "file.txt")
	end)
end)

test.suite("PathWin32BasenameSuite", function()
	test.case("basename_windows_absolute_path", function()
		local result = path.win32.basename("C:\\Users\\username\\Documents\\file.txt")
		test.assert.eq(result, "file.txt")
	end)

	test.case("basename_windows_unc_path", function()
		local result = path.win32.basename("\\\\server\\share\\folder\\file.txt")
		test.assert.eq(result, "file.txt")
	end)

	test.case("basename_single_file", function()
		local result = path.win32.basename("file.txt")
		test.assert.eq(result, "file.txt")
	end)

	test.case("basename_directory_no_extension", function()
		local result = path.win32.basename("C:\\Users\\username\\Documents")
		test.assert.eq(result, "Documents")
	end)

	test.case("basename_empty_path", function()
		local result = path.win32.basename("")
		test.assert.eq(result, nil)
	end)

	test.case("basename_root_path", function()
		local result = path.win32.basename("C:\\")
		test.assert.eq(result, nil)
	end)

	test.case("basename_pathobj", function()
		local pathObj: win32.WindowsPath = {
			parts = { "folder", "subfolder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.basename(pathObj)
		test.assert.eq(result, "file.txt")
	end)

	test.case("basename_mixed_separators", function()
		local result = path.win32.basename("/home/user\\documents/file.txt")
		test.assert.eq(result, "file.txt")
	end)
end)

test.suite("PathWin32FormatSuite", function()
	test.case("format_windows_absolute_path", function()
		local pathObj: win32.WindowsPath = {
			parts = { "Users", "username", "Documents", "file.txt" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.format(pathObj)
		test.assert.eq(result, "C:\\Users\\username\\Documents\\file.txt")
	end)

	test.case("format_windows_relative_with_drive", function()
		local pathObj: win32.WindowsPath = {
			parts = { "Documents", "file.txt" },
			kind = "relative",
			driveLetter = "C",
		}
		local result = path.win32.format(pathObj)
		test.assert.eq(result, "C:Documents\\file.txt")
	end)

	test.case("format_windows_unc_path", function()
		local pathObj: win32.WindowsPath = {
			parts = { "server", "share", "folder", "file.txt" },
			kind = "unc",
			driveLetter = nil,
		}
		local result = path.win32.format(pathObj)
		test.assert.eq(result, "\\\\server\\share\\folder\\file.txt")
	end)

	test.case("format_empty_relative_path", function()
		local pathObj: win32.WindowsPath = {
			parts = {},
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.format(pathObj)
		test.assert.eq(result, ".")
	end)

	test.case("format_empty_relative_path_with_drive", function()
		local pathObj: win32.WindowsPath = {
			parts = {},
			kind = "relative",
			driveLetter = "C",
		}
		local result = path.win32.format(pathObj)
		test.assert.eq(result, "C:")
	end)

	test.case("format_root_path_with_drive", function()
		local pathObj: win32.WindowsPath = {
			parts = {},
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.format(pathObj)
		test.assert.eq(result, "C:\\")
	end)

	test.case("format_string_returns_same", function()
		local result = path.win32.format("/home/user/file.txt")
		test.assert.eq(result, "/home/user/file.txt")
	end)
end)

test.suite("PathWin32DirnameSuite", function()
	test.case("dirname_windows_absolute_path", function()
		local result = path.win32.dirname("C:\\Users\\username\\Documents\\file.txt")
		test.assert.eq(result, "C:\\Users\\username\\Documents")
	end)

	test.case("dirname_windows_unc_path", function()
		local result = path.win32.dirname("\\\\server\\share\\folder\\file.txt")
		test.assert.eq(result, "\\\\server\\share\\folder")
	end)

	test.case("dirname_single_file", function()
		local result = path.win32.dirname("file.txt")
		test.assert.eq(result, ".")
	end)

	test.case("dirname_empty_path", function()
		local result = path.win32.dirname("")
		test.assert.eq(result, ".")
	end)

	test.case("dirname_windows_root", function()
		local result = path.win32.dirname("C:\\")
		test.assert.eq(result, "C:\\")
	end)

	test.case("dirname_pathobj", function()
		local pathObj: win32.WindowsPath = {
			parts = { "folder", "subfolder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.dirname(pathObj)
		test.assert.eq(result, "folder\\subfolder")
	end)

	test.case("dirname_windows_relative_with_drive", function()
		local result = path.win32.dirname("C:Documents\\file.txt")
		test.assert.eq(result, "C:Documents")
	end)
end)

test.suite("PathWin32ExtnameSuite", function()
	test.case("extname_simple_extension", function()
		local result = path.win32.extname("C:\\Users\\username\\file.txt")
		test.assert.eq(result, ".txt")
	end)

	test.case("extname_multiple_dots", function()
		local result = path.win32.extname("C:\\Users\\username\\archive.tar.gz")
		test.assert.eq(result, ".gz")
	end)

	test.case("extname_no_extension", function()
		local result = path.win32.extname("C:\\Users\\username\\README")
		test.assert.eq(result, "")
	end)

	test.case("extname_hidden_file_with_extension", function()
		local result = path.win32.extname("C:\\Users\\username\\.bashrc")
		test.assert.eq(result, "")
	end)

	test.case("extname_hidden_file_with_real_extension", function()
		local result = path.win32.extname("C:\\Users\\username\\.config.json")
		test.assert.eq(result, ".json")
	end)

	test.case("extname_windows_path", function()
		local result = path.win32.extname("C:\\Users\\username\\document.docx")
		test.assert.eq(result, ".docx")
	end)

	test.case("extname_directory_path", function()
		local result = path.win32.extname("C:\\Users\\username\\documents")
		test.assert.eq(result, "")
	end)

	test.case("extname_empty_path", function()
		local result = path.win32.extname("")
		test.assert.eq(result, "")
	end)

	test.case("extname_root_path", function()
		local result = path.win32.extname("C:\\")
		test.assert.eq(result, "")
	end)

	test.case("extname_pathobj", function()
		local pathObj: win32.WindowsPath = {
			parts = { "folder", "file.pdf" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.extname(pathObj)
		test.assert.eq(result, ".pdf")
	end)

	test.case("extname_dot_only", function()
		local result = path.win32.extname("C:\\Users\\username\\file.")
		test.assert.eq(result, ".")
	end)

	test.case("extname_filename_is_dot", function()
		local result = path.win32.extname("C:\\Users\\username\\.")
		test.assert.eq(result, "")
	end)

	test.case("extname_filename_is_dotdot", function()
		local result = path.win32.extname("C:\\Users\\username\\..")
		test.assert.eq(result, "")
	end)
end)

test.suite("PathWin32IsAbsoluteSuite", function()
	test.case("isAbsolute_windows_absolute_path", function()
		local result = path.win32.isabsolute("C:\\Users\\username\\Documents\\file.txt")
		test.assert.eq(result, true)
	end)

	test.case("isAbsolute_windows_relative_path", function()
		local result = path.win32.isabsolute("Documents\\file.txt")
		test.assert.eq(result, false)
	end)

	test.case("isAbsolute_windows_relative_with_drive", function()
		local result = path.win32.isabsolute("C:Documents\\file.txt")
		test.assert.eq(result, false)
	end)

	test.case("isAbsolute_windows_unc_path", function()
		local result = path.win32.isabsolute("\\\\server\\share\\folder\\file.txt")
		test.assert.eq(result, true)
	end)

	test.case("isAbsolute_root_path", function()
		local result = path.win32.isabsolute("C:\\")
		test.assert.eq(result, true)
	end)

	test.case("isAbsolute_empty_path", function()
		local result = path.win32.isabsolute("")
		test.assert.eq(result, false)
	end)

	test.case("isAbsolute_pathobj_absolute", function()
		local pathObj: win32.WindowsPath = {
			parts = { "home", "user", "file.txt" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.isabsolute(pathObj)
		test.assert.eq(result, true)
	end)

	test.case("isAbsolute_pathobj_relative", function()
		local pathObj: win32.WindowsPath = {
			parts = { "folder", "file.txt" },
			kind = "relative",
			driveLetter = nil,
		}
		local result = path.win32.isabsolute(pathObj)
		test.assert.eq(result, false)
	end)
end)

test.suite("PathWin32NormalizeSuite", function()
	test.case("normalize_removes_current_directory", function()
		local result = path.win32.normalize("C:\\Users\\.\\username\\Documents")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
		test.assert.eq(result.parts[3], "Documents")
	end)

	test.case("normalize_resolves_parent_directory", function()
		local result = path.win32.normalize("C:\\Users\\username\\..\\Documents")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "Documents")
	end)

	test.case("normalize_multiple_dots", function()
		local result = path.win32.normalize("C:\\Users\\username\\.\\Documents\\..\\files\\.\\")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
		test.assert.eq(result.parts[3], "files")
	end)

	test.case("normalize_relative_path", function()
		local result = path.win32.normalize("Documents\\.\\subfolder\\..\\file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "Documents")
		test.assert.eq(result.parts[2], "file.txt")
	end)

	test.case("normalize_removes_empty_segments", function()
		local result = path.win32.normalize("C:\\Users\\\\username\\\\\\Documents")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
		test.assert.eq(result.parts[3], "Documents")
	end)

	test.case("normalize_parent_beyond_root", function()
		local result = path.win32.normalize("C:\\Users\\..\\..\\")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 0)
	end)

	test.case("normalize_unc_path", function()
		local result = path.win32.normalize("\\\\server\\share\\.\\folder\\..\\files")
		test.assert.eq(result.kind, "unc")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "server")
		test.assert.eq(result.parts[2], "share")
		test.assert.eq(result.parts[3], "files")
	end)

	test.case("normalize_relative_with_drive", function()
		local result = path.win32.normalize("C:Documents\\.\\subfolder\\..\\file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "Documents")
		test.assert.eq(result.parts[2], "file.txt")
	end)

	test.case("normalize_parent_directory_only", function()
		local result = path.win32.normalize("..")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 1)
		test.assert.eq(result.parts[1], "..")
	end)

	test.case("normalize_multiple_parent_directories", function()
		local result = path.win32.normalize("..\\..\\..")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "..")
		test.assert.eq(result.parts[2], "..")
		test.assert.eq(result.parts[3], "..")
	end)

	test.case("normalize_parent_then_folder", function()
		local result = path.win32.normalize("..\\folder\\file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "..")
		test.assert.eq(result.parts[2], "folder")
		test.assert.eq(result.parts[3], "file.txt")
	end)

	test.case("normalize_folder_then_multiple_parents", function()
		local result = path.win32.normalize("folder\\subfolder\\..\\..\\other")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 1)
		test.assert.eq(result.parts[1], "other")
	end)

	test.case("normalize_pathobj", function()
		local pathObj: win32.WindowsPath = {
			parts = { "Users", ".", "username", "..", "Documents" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.normalize(pathObj)
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "Documents")
	end)

	test.case("normalize_relative_with_drive_and_parent", function()
		local result = path.win32.normalize("C:..\\folder\\file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "..")
		test.assert.eq(result.parts[2], "folder")
		test.assert.eq(result.parts[3], "file.txt")
	end)
end)

test.suite("PathWin32JoinSuite", function()
	test.case("join_absolute_and_relative", function()
		local result = path.win32.join("C:\\Users\\username", "Documents", "file.txt")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
		test.assert.eq(result.parts[3], "Documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("join_relative_paths", function()
		local result = path.win32.join("Documents", "subfolder", "file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "Documents")
		test.assert.eq(result.parts[2], "subfolder")
		test.assert.eq(result.parts[3], "file.txt")
	end)

	test.case("join_drive_relative_paths", function()
		local result = path.win32.join("C:Documents", "subfolder", "file.txt")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "Documents")
		test.assert.eq(result.parts[2], "subfolder")
		test.assert.eq(result.parts[3], "file.txt")
	end)

	test.case("join_unc_and_relative", function()
		local result = path.win32.join("\\\\server\\share", "folder", "file.txt")
		test.assert.eq(result.kind, "unc")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "server")
		test.assert.eq(result.parts[2], "share")
		test.assert.eq(result.parts[3], "folder")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("join_no_arguments", function()
		local result = path.win32.join()
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("join_pathobj_and_string", function()
		local pathObj: win32.WindowsPath = {
			parts = { "Users", "username" },
			kind = "absolute",
			driveLetter = "C",
		}
		local result = path.win32.join(pathObj, "Documents\\file.txt")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
		test.assert.eq(result.parts[3], "Documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("join_error_on_absolute_addend", function()
		local success, _ = pcall(function()
			return path.win32.join("C:\\Users", "D:\\absolute\\path")
		end)
		test.assert.eq(success, false)
	end)

	test.case("join_error_on_unc_addend", function()
		local success, _ = pcall(function()
			return path.win32.join("C:\\Users", "\\\\server\\share")
		end)
		test.assert.eq(success, false)
	end)

	test.case("join_error_on_incompatible_drives", function()
		local success, _ = pcall(function()
			return path.win32.join("C:Documents", "D:other")
		end)
		test.assert.eq(success, false)
	end)

	test.case("join_compatible_drives", function()
		local result = path.win32.join("C:Documents", "C:subfolder")
		test.assert.eq(result.kind, "relative")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "Documents")
		test.assert.eq(result.parts[2], "subfolder")
	end)
end)

test.suite("PathWin32ResolveSuite", function()
	test.case("resolve_absolute_path", function()
		local result = path.win32.resolve("C:\\Users\\username\\Documents\\file.txt")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
		test.assert.eq(result.parts[3], "Documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("resolve_relative_path_from_cwd", function()
		-- This test assumes we're in some working directory
		local result = path.win32.resolve("Documents\\file.txt")
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		if system.os == "windows" then
			test.assert.eq(result.kind, "absolute")
		else
			test.assert.eq(result.kind, "relative")
		end
		-- The exact parts will depend on the current working directory
		-- But we can check that it ends with our relative path
		-- In an ideal world, we'd mock `process.cwd`
		local endIndex = #result.parts
		test.assert.eq(result.parts[endIndex - 1], "Documents")
		test.assert.eq(result.parts[endIndex], "file.txt")
	end)

	test.case("resolve_multiple_paths", function()
		local result = path.win32.resolve("C:\\Users", "username", "..\\admin", "Documents")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "admin")
		test.assert.eq(result.parts[3], "Documents")
	end)

	test.case("resolve_with_absolute_in_middle", function()
		local result = path.win32.resolve("relative", "D:\\absolute\\path", "more")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "D")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "absolute")
		test.assert.eq(result.parts[2], "path")
		test.assert.eq(result.parts[3], "more")
	end)

	test.case("resolve_unc_path", function()
		local result = path.win32.resolve("\\\\server\\share\\folder")
		test.assert.eq(result.kind, "unc")
		test.assert.eq(result.driveLetter, nil)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "server")
		test.assert.eq(result.parts[2], "share")
		test.assert.eq(result.parts[3], "folder")
	end)

	test.case("resolve_no_arguments", function()
		-- Should return normalized current working directory
		local result = path.win32.resolve()
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		if system.os == "windows" then
			test.assert.eq(result.kind, "absolute")
		else
			test.assert.eq(result.kind, "relative")
		end
		-- Can't test exact parts since cwd varies
	end)

	test.case("resolve_drive_relative_path", function()
		local result = path.win32.resolve("C:Documents\\file.txt")
		-- Absolute unix paths will be parsed as relative Windows paths because they don't have drive letters
		if system.os == "windows" then
			test.assert.eq(result.kind, "absolute")
		else
			test.assert.eq(result.kind, "relative")
		end
		test.assert.eq(result.driveLetter, "C")
		-- The exact parts depend on cwd, but should be absolute
		local endIndex = #result.parts
		test.assert.eq(result.parts[endIndex - 1], "Documents")
		test.assert.eq(result.parts[endIndex], "file.txt")
	end)

	test.case("resolve_with_dot_segments", function()
		local result = path.win32.resolve("C:\\Users\\username", "..\\admin\\.\\Documents")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "admin")
		test.assert.eq(result.parts[3], "Documents")
	end)

	test.case("resolve_empty_strings", function()
		local result = path.win32.resolve("", "", "C:\\Users\\username")
		test.assert.eq(result.kind, "absolute")
		test.assert.eq(result.driveLetter, "C")
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "Users")
		test.assert.eq(result.parts[2], "username")
	end)
end)

test.run()
