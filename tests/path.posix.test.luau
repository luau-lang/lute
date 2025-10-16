local system = require("@std/system")
local test = require("@std/test")

local path = require("@std/path")
local posix = require("@std/path/posix")

test.suite("PathPosixParseSuite", function()
	test.case("parse_posix_absolute_path", function()
		local result = path.posix.parse("/home/user/documents/file.txt")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("parse_posix_relative_path", function()
		local result = path.posix.parse("documents/file.txt")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "documents")
		test.assert.eq(result.parts[2], "file.txt")
	end)

	test.case("parse_empty_string", function()
		local result = path.posix.parse("")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("parse_root_path", function()
		local result = path.posix.parse("/")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("parse_single_file", function()
		local result = path.posix.parse("file.txt")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 1)
		test.assert.eq(result.parts[1], "file.txt")
	end)

	test.case("parse_pathobj_returns_same", function()
		local originalPath: posix.path = {
			parts = { "folder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.parse(originalPath)
		test.assert.eq(result, originalPath)
	end)
end)

test.suite("PathPosixBasenameSuite", function()
	test.case("basename_posix_absolute_path", function()
		local result = path.posix.basename("/home/user/documents/file.txt")
		test.assert.eq(result, "file.txt")
	end)

	test.case("basename_posix_relative_path", function()
		local result = path.posix.basename("documents/file.txt")
		test.assert.eq(result, "file.txt")
	end)

	test.case("basename_single_file", function()
		local result = path.posix.basename("file.txt")
		test.assert.eq(result, "file.txt")
	end)

	test.case("basename_directory_no_extension", function()
		local result = path.posix.basename("/home/user/documents")
		test.assert.eq(result, "documents")
	end)

	test.case("basename_empty_path", function()
		local result = path.posix.basename("")
		test.assert.eq(result, nil)
	end)

	test.case("basename_root_path", function()
		local result = path.posix.basename("/")
		test.assert.eq(result, nil)
	end)

	test.case("basename_pathobj", function()
		local pathobj: posix.path = {
			parts = { "folder", "subfolder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.basename(pathobj)
		test.assert.eq(result, "file.txt")
	end)
end)

test.suite("PathPosixFormatSuite", function()
	test.case("format_posix_absolute_path", function()
		local pathobj: posix.path = {
			parts = { "home", "user", "documents", "file.txt" },
			absolute = true,
		}
		local result = path.posix.format(pathobj)
		test.assert.eq(result, "/home/user/documents/file.txt")
	end)

	test.case("format_posix_relative_path", function()
		local pathobj: posix.path = {
			parts = { "documents", "file.txt" },
			absolute = false,
		}
		local result = path.posix.format(pathobj)
		test.assert.eq(result, "documents/file.txt")
	end)

	test.case("format_empty_relative_path", function()
		local pathobj: posix.path = {
			parts = {},
			absolute = false,
		}
		local result = path.posix.format(pathobj)
		test.assert.eq(result, ".")
	end)

	test.case("format_root_path", function()
		local pathobj: posix.path = {
			parts = {},
			absolute = true,
		}
		local result = path.posix.format(pathobj)
		test.assert.eq(result, "/")
	end)

	test.case("format_string_returns_same", function()
		local result = path.posix.format("/home/user/file.txt")
		test.assert.eq(result, "/home/user/file.txt")
	end)
end)

test.suite("PathPosixDirnameSuite", function()
	test.case("dirname_posix_absolute_path", function()
		local result = path.posix.dirname("/home/user/documents/file.txt")
		test.assert.eq(result, "/home/user/documents")
	end)

	test.case("dirname_posix_relative_path", function()
		local result = path.posix.dirname("documents/file.txt")
		test.assert.eq(result, "documents")
	end)

	test.case("dirname_single_file", function()
		local result = path.posix.dirname("file.txt")
		test.assert.eq(result, ".")
	end)

	test.case("dirname_nested_directory", function()
		local result = path.posix.dirname("/home/user/documents/subfolder")
		test.assert.eq(result, "/home/user/documents")
	end)

	test.case("dirname_empty_path", function()
		local result = path.posix.dirname("")
		test.assert.eq(result, ".")
	end)

	test.case("dirname_root_path", function()
		local result = path.posix.dirname("/")
		test.assert.eq(result, "/")
	end)

	test.case("dirname_pathobj", function()
		local pathobj: posix.path = {
			parts = { "folder", "subfolder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.dirname(pathobj)
		test.assert.eq(result, "folder/subfolder")
	end)
end)

test.suite("PathPosixExtnameSuite", function()
	test.case("extname_simple_extension", function()
		local result = path.posix.extname("/home/user/file.txt")
		test.assert.eq(result, ".txt")
	end)

	test.case("extname_multiple_dots", function()
		local result = path.posix.extname("/home/user/archive.tar.gz")
		test.assert.eq(result, ".gz")
	end)

	test.case("extname_no_extension", function()
		local result = path.posix.extname("/home/user/README")
		test.assert.eq(result, "")
	end)

	test.case("extname_hidden_file_with_extension", function()
		local result = path.posix.extname("/home/user/.bashrc")
		test.assert.eq(result, "")
	end)

	test.case("extname_hidden_file_with_real_extension", function()
		local result = path.posix.extname("/home/user/.config.json")
		test.assert.eq(result, ".json")
	end)

	test.case("extname_directory_path", function()
		local result = path.posix.extname("/home/user/documents")
		test.assert.eq(result, "")
	end)

	test.case("extname_empty_path", function()
		local result = path.posix.extname("")
		test.assert.eq(result, "")
	end)

	test.case("extname_root_path", function()
		local result = path.posix.extname("/")
		test.assert.eq(result, "")
	end)

	test.case("extname_pathobj", function()
		local pathobj: posix.path = {
			parts = { "folder", "file.pdf" },
			absolute = false,
		}
		local result = path.posix.extname(pathobj)
		test.assert.eq(result, ".pdf")
	end)

	test.case("extname_dot_only", function()
		local result = path.posix.extname("/home/user/file.")
		test.assert.eq(result, ".")
	end)

	test.case("extname_filename_is_dot", function()
		local result = path.posix.extname("/home/user/.")
		test.assert.eq(result, "")
	end)

	test.case("extname_filename_is_dotdot", function()
		local result = path.posix.extname("/home/user/..")
		test.assert.eq(result, "")
	end)
end)

test.suite("PathPosixIsAbsoluteSuite", function()
	test.case("absolute_posix_absolute_path", function()
		local result = path.posix.isabsolute("/home/user/documents/file.txt")
		test.assert.eq(result, true)
	end)

	test.case("absolute_posix_relative_path", function()
		local result = path.posix.isabsolute("documents/file.txt")
		test.assert.eq(result, false)
	end)

	test.case("absolute_root_path", function()
		local result = path.posix.isabsolute("/")
		test.assert.eq(result, true)
	end)

	test.case("absolute_empty_path", function()
		local result = path.posix.isabsolute("")
		test.assert.eq(result, false)
	end)

	test.case("absolute_pathobj_absolute", function()
		local pathobj: posix.path = {
			parts = { "home", "user", "file.txt" },
			absolute = true,
		}
		local result = path.posix.isabsolute(pathobj)
		test.assert.eq(result, true)
	end)

	test.case("absolute_pathobj_relative", function()
		local pathobj: posix.path = {
			parts = { "folder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.isabsolute(pathobj)
		test.assert.eq(result, false)
	end)
end)

test.suite("PathPosixNormalizeSuite", function()
	test.case("normalize_removes_current_directory", function()
		local result = path.posix.normalize("/home/./user/documents")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "documents")
	end)

	test.case("normalize_resolves_parent_directory", function()
		local result = path.posix.normalize("/home/user/../documents")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "documents")
	end)

	test.case("normalize_multiple_dots", function()
		local result = path.posix.normalize("/home/user/./documents/../files/./")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "files")
	end)

	test.case("normalize_relative_path", function()
		local result = path.posix.normalize("documents/./subfolder/../file.txt")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "documents")
		test.assert.eq(result.parts[2], "file.txt")
	end)

	test.case("normalize_removes_empty_segments", function()
		local result = path.posix.normalize("/home//user///documents")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "documents")
	end)

	test.case("normalize_parent_beyond_root", function()
		local result = path.posix.normalize("/home/../..")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("normalize_empty_path", function()
		local result = path.posix.normalize("")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("normalize_only_dots", function()
		local result = path.posix.normalize("./././.")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("normalize_pathobj", function()
		local pathobj: posix.path = {
			parts = { "home", ".", "user", "..", "documents" },
			absolute = true,
		}
		local result = path.posix.normalize(pathobj)
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "documents")
	end)

	test.case("normalize_parent_directory_only", function()
		local result = path.posix.normalize("..")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 1)
		test.assert.eq(result.parts[1], "..")
	end)

	test.case("normalize_multiple_parent_directories", function()
		local result = path.posix.normalize("../../..")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "..")
		test.assert.eq(result.parts[2], "..")
		test.assert.eq(result.parts[3], "..")
	end)

	test.case("normalize_parent_then_folder", function()
		local result = path.posix.normalize("../folder/file.txt")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "..")
		test.assert.eq(result.parts[2], "folder")
		test.assert.eq(result.parts[3], "file.txt")
	end)

	test.case("normalize_multiple_parents_then_folder", function()
		local result = path.posix.normalize("../../folder/subfolder")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "..")
		test.assert.eq(result.parts[2], "..")
		test.assert.eq(result.parts[3], "folder")
		test.assert.eq(result.parts[4], "subfolder")
	end)

	test.case("normalize_folder_then_multiple_parents", function()
		local result = path.posix.normalize("folder/subfolder/../../other")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 1)
		test.assert.eq(result.parts[1], "other")
	end)
end)

test.suite("PathPosixJoinSuite", function()
	test.case("join_absolute_and_relative", function()
		local result = path.posix.join("/home/user", "documents", "file.txt")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("join_relative_paths", function()
		local result = path.posix.join("documents", "subfolder", "file.txt")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "documents")
		test.assert.eq(result.parts[2], "subfolder")
		test.assert.eq(result.parts[3], "file.txt")
	end)

	test.case("join_empty_parts", function()
		local result = path.posix.join("folder", "", "file.txt")
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "folder")
		test.assert.eq(result.parts[2], "file.txt")
	end)

	test.case("join_no_arguments", function()
		local result = path.posix.join()
		test.assert.eq(result.absolute, false)
		test.assert.eq(#result.parts, 0)
	end)

	test.case("join_single_argument", function()
		local result = path.posix.join("/home/user")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
	end)

	test.case("join_pathobj_and_string", function()
		local pathobj: posix.path = {
			parts = { "home", "user" },
			absolute = true,
		}
		local result = path.posix.join(pathobj, "documents/file.txt")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("join_error_on_absolute_addend", function()
		local success, _ = pcall(function()
			return path.posix.join("/home/user", "/absolute/path")
		end)
		test.assert.eq(success, false)
	end)
end)

test.suite("PathPosixResolveSuite", function()
	test.case("resolve_absolute_path", function()
		local result = path.posix.resolve("/home/user/documents/file.txt")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 4)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
		test.assert.eq(result.parts[3], "documents")
		test.assert.eq(result.parts[4], "file.txt")
	end)

	test.case("resolve_relative_path_from_cwd", function()
		-- This test assumes we're in some working directory
		local result = path.posix.resolve("documents/file.txt")
		-- Absolute Windows paths will be parsed as relative posix paths because they don't start with /
		test.assert.eq(result.absolute, system.os ~= "windows")
		-- The exact parts will depend on the current working directory
		-- But we can check that it ends with our relative path
		local endIndex = #result.parts
		test.assert.eq(result.parts[endIndex - 1], "documents")
		test.assert.eq(result.parts[endIndex], "file.txt")
	end)

	test.case("resolve_multiple_paths", function()
		local result = path.posix.resolve("/home", "user", "../admin", "documents")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "admin")
		test.assert.eq(result.parts[3], "documents")
	end)

	test.case("resolve_with_absolute_in_middle", function()
		local result = path.posix.resolve("relative", "/absolute/path", "more")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "absolute")
		test.assert.eq(result.parts[2], "path")
		test.assert.eq(result.parts[3], "more")
	end)

	test.case("resolve_no_arguments", function()
		-- Should return normalized current working directory
		local result = path.posix.resolve()
		-- Absolute Windows paths will be parsed as relative posix paths because they don't start with /
		test.assert.eq(result.absolute, system.os ~= "windows")
		-- Can't test exact parts since cwd varies
	end)

	test.case("resolve_empty_strings", function()
		local result = path.posix.resolve("", "", "/home/user")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 2)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "user")
	end)

	test.case("resolve_with_dot_segments", function()
		local result = path.posix.resolve("/home/user", "../admin/./documents")
		test.assert.eq(result.absolute, true)
		test.assert.eq(#result.parts, 3)
		test.assert.eq(result.parts[1], "home")
		test.assert.eq(result.parts[2], "admin")
		test.assert.eq(result.parts[3], "documents")
	end)
end)

test.run()
