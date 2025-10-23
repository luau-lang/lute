local system = require("@std/system")
local test = require("@std/test")

local path = require("@std/path")
local posix = require("@std/path/posix")

test.suite("PathPosixParseSuite", function(suite)
	suite:case("parse_posix_absolute_path", function(assert)
		local result = path.posix.parse("/home/user/documents/file.txt")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("parse_posix_relative_path", function(assert)
		local result = path.posix.parse("documents/file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("parse_empty_string", function(assert)
		local result = path.posix.parse("")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("parse_root_path", function(assert)
		local result = path.posix.parse("/")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 0)
	end)

	suite:case("parse_single_file", function(assert)
		local result = path.posix.parse("file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "file.txt")
	end)

	suite:case("parse_pathobj_returns_same", function(assert)
		local originalPath: posix.path = {
			parts = { "folder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.parse(originalPath)
		assert.eq(result, originalPath)
	end)
end)

test.suite("PathPosixBasenameSuite", function(suite)
	suite:case("basename_posix_absolute_path", function(assert)
		local result = path.posix.basename("/home/user/documents/file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basename_posix_relative_path", function(assert)
		local result = path.posix.basename("documents/file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basename_single_file", function(assert)
		local result = path.posix.basename("file.txt")
		assert.eq(result, "file.txt")
	end)

	suite:case("basename_directory_no_extension", function(assert)
		local result = path.posix.basename("/home/user/documents")
		assert.eq(result, "documents")
	end)

	suite:case("basename_empty_path", function(assert)
		local result = path.posix.basename("")
		assert.eq(result, nil)
	end)

	suite:case("basename_root_path", function(assert)
		local result = path.posix.basename("/")
		assert.eq(result, nil)
	end)

	suite:case("basename_pathobj", function(assert)
		local pathobj: posix.path = {
			parts = { "folder", "subfolder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.basename(pathobj)
		assert.eq(result, "file.txt")
	end)
end)

test.suite("PathPosixFormatSuite", function(suite)
	suite:case("format_posix_absolute_path", function(assert)
		local pathobj: posix.path = {
			parts = { "home", "user", "documents", "file.txt" },
			absolute = true,
		}
		local result = path.posix.format(pathobj)
		assert.eq(result, "/home/user/documents/file.txt")
	end)

	suite:case("format_posix_relative_path", function(assert)
		local pathobj: posix.path = {
			parts = { "documents", "file.txt" },
			absolute = false,
		}
		local result = path.posix.format(pathobj)
		assert.eq(result, "documents/file.txt")
	end)

	suite:case("format_empty_relative_path", function(assert)
		local pathobj: posix.path = {
			parts = {},
			absolute = false,
		}
		local result = path.posix.format(pathobj)
		assert.eq(result, ".")
	end)

	suite:case("format_root_path", function(assert)
		local pathobj: posix.path = {
			parts = {},
			absolute = true,
		}
		local result = path.posix.format(pathobj)
		assert.eq(result, "/")
	end)

	suite:case("format_string_returns_same", function(assert)
		local result = path.posix.format("/home/user/file.txt")
		assert.eq(result, "/home/user/file.txt")
	end)
end)

test.suite("PathPosixDirnameSuite", function(suite)
	suite:case("dirname_posix_absolute_path", function(assert)
		local result = path.posix.dirname("/home/user/documents/file.txt")
		assert.eq(result, "/home/user/documents")
	end)

	suite:case("dirname_posix_relative_path", function(assert)
		local result = path.posix.dirname("documents/file.txt")
		assert.eq(result, "documents")
	end)

	suite:case("dirname_single_file", function(assert)
		local result = path.posix.dirname("file.txt")
		assert.eq(result, ".")
	end)

	suite:case("dirname_nested_directory", function(assert)
		local result = path.posix.dirname("/home/user/documents/subfolder")
		assert.eq(result, "/home/user/documents")
	end)

	suite:case("dirname_empty_path", function(assert)
		local result = path.posix.dirname("")
		assert.eq(result, ".")
	end)

	suite:case("dirname_root_path", function(assert)
		local result = path.posix.dirname("/")
		assert.eq(result, "/")
	end)

	suite:case("dirname_pathobj", function(assert)
		local pathobj: posix.path = {
			parts = { "folder", "subfolder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.dirname(pathobj)
		assert.eq(result, "folder/subfolder")
	end)
end)

test.suite("PathPosixExtnameSuite", function(suite)
	suite:case("extname_simple_extension", function(assert)
		local result = path.posix.extname("/home/user/file.txt")
		assert.eq(result, ".txt")
	end)

	suite:case("extname_multiple_dots", function(assert)
		local result = path.posix.extname("/home/user/archive.tar.gz")
		assert.eq(result, ".gz")
	end)

	suite:case("extname_no_extension", function(assert)
		local result = path.posix.extname("/home/user/README")
		assert.eq(result, "")
	end)

	suite:case("extname_hidden_file_with_extension", function(assert)
		local result = path.posix.extname("/home/user/.bashrc")
		assert.eq(result, "")
	end)

	suite:case("extname_hidden_file_with_real_extension", function(assert)
		local result = path.posix.extname("/home/user/.config.json")
		assert.eq(result, ".json")
	end)

	suite:case("extname_directory_path", function(assert)
		local result = path.posix.extname("/home/user/documents")
		assert.eq(result, "")
	end)

	suite:case("extname_empty_path", function(assert)
		local result = path.posix.extname("")
		assert.eq(result, "")
	end)

	suite:case("extname_root_path", function(assert)
		local result = path.posix.extname("/")
		assert.eq(result, "")
	end)

	suite:case("extname_pathobj", function(assert)
		local pathobj: posix.path = {
			parts = { "folder", "file.pdf" },
			absolute = false,
		}
		local result = path.posix.extname(pathobj)
		assert.eq(result, ".pdf")
	end)

	suite:case("extname_dot_only", function(assert)
		local result = path.posix.extname("/home/user/file.")
		assert.eq(result, ".")
	end)

	suite:case("extname_filename_is_dot", function(assert)
		local result = path.posix.extname("/home/user/.")
		assert.eq(result, "")
	end)

	suite:case("extname_filename_is_dotdot", function(assert)
		local result = path.posix.extname("/home/user/..")
		assert.eq(result, "")
	end)
end)

test.suite("PathPosixIsAbsoluteSuite", function(suite)
	suite:case("absolute_posix_absolute_path", function(assert)
		local result = path.posix.isabsolute("/home/user/documents/file.txt")
		assert.eq(result, true)
	end)

	suite:case("absolute_posix_relative_path", function(assert)
		local result = path.posix.isabsolute("documents/file.txt")
		assert.eq(result, false)
	end)

	suite:case("absolute_root_path", function(assert)
		local result = path.posix.isabsolute("/")
		assert.eq(result, true)
	end)

	suite:case("absolute_empty_path", function(assert)
		local result = path.posix.isabsolute("")
		assert.eq(result, false)
	end)

	suite:case("absolute_pathobj_absolute", function(assert)
		local pathobj: posix.path = {
			parts = { "home", "user", "file.txt" },
			absolute = true,
		}
		local result = path.posix.isabsolute(pathobj)
		assert.eq(result, true)
	end)

	suite:case("absolute_pathobj_relative", function(assert)
		local pathobj: posix.path = {
			parts = { "folder", "file.txt" },
			absolute = false,
		}
		local result = path.posix.isabsolute(pathobj)
		assert.eq(result, false)
	end)
end)

test.suite("PathPosixNormalizeSuite", function(suite)
	suite:case("normalize_removes_current_directory", function(assert)
		local result = path.posix.normalize("/home/./user/documents")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
	end)

	suite:case("normalize_resolves_parent_directory", function(assert)
		local result = path.posix.normalize("/home/user/../documents")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "documents")
	end)

	suite:case("normalize_multiple_dots", function(assert)
		local result = path.posix.normalize("/home/user/./documents/../files/./")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "files")
	end)

	suite:case("normalize_relative_path", function(assert)
		local result = path.posix.normalize("documents/./subfolder/../file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "documents")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("normalize_removes_empty_segments", function(assert)
		local result = path.posix.normalize("/home//user///documents")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
	end)

	suite:case("normalize_parent_beyond_root", function(assert)
		local result = path.posix.normalize("/home/../..")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalize_empty_path", function(assert)
		local result = path.posix.normalize("")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalize_only_dots", function(assert)
		local result = path.posix.normalize("./././.")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("normalize_pathobj", function(assert)
		local pathobj: posix.path = {
			parts = { "home", ".", "user", "..", "documents" },
			absolute = true,
		}
		local result = path.posix.normalize(pathobj)
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "documents")
	end)

	suite:case("normalize_parent_directory_only", function(assert)
		local result = path.posix.normalize("..")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "..")
	end)

	suite:case("normalize_multiple_parent_directories", function(assert)
		local result = path.posix.normalize("../../..")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "..")
		assert.eq(result.parts[3], "..")
	end)

	suite:case("normalize_parent_then_folder", function(assert)
		local result = path.posix.normalize("../folder/file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "folder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("normalize_multiple_parents_then_folder", function(assert)
		local result = path.posix.normalize("../../folder/subfolder")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "..")
		assert.eq(result.parts[2], "..")
		assert.eq(result.parts[3], "folder")
		assert.eq(result.parts[4], "subfolder")
	end)

	suite:case("normalize_folder_then_multiple_parents", function(assert)
		local result = path.posix.normalize("folder/subfolder/../../other")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 1)
		assert.eq(result.parts[1], "other")
	end)
end)

test.suite("PathPosixJoinSuite", function(suite)
	suite:case("join_absolute_and_relative", function(assert)
		local result = path.posix.join("/home/user", "documents", "file.txt")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("join_relative_paths", function(assert)
		local result = path.posix.join("documents", "subfolder", "file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "documents")
		assert.eq(result.parts[2], "subfolder")
		assert.eq(result.parts[3], "file.txt")
	end)

	suite:case("join_empty_parts", function(assert)
		local result = path.posix.join("folder", "", "file.txt")
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "folder")
		assert.eq(result.parts[2], "file.txt")
	end)

	suite:case("join_no_arguments", function(assert)
		local result = path.posix.join()
		assert.eq(result.absolute, false)
		assert.eq(#result.parts, 0)
	end)

	suite:case("join_single_argument", function(assert)
		local result = path.posix.join("/home/user")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
	end)

	suite:case("join_pathobj_and_string", function(assert)
		local pathobj: posix.path = {
			parts = { "home", "user" },
			absolute = true,
		}
		local result = path.posix.join(pathobj, "documents/file.txt")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("join_error_on_absolute_addend", function(assert)
		local success, _ = pcall(function()
			return path.posix.join("/home/user", "/absolute/path")
		end)
		assert.eq(success, false)
	end)
end)

test.suite("PathPosixResolveSuite", function(suite)
	suite:case("resolve_absolute_path", function(assert)
		local result = path.posix.resolve("/home/user/documents/file.txt")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 4)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
		assert.eq(result.parts[3], "documents")
		assert.eq(result.parts[4], "file.txt")
	end)

	suite:case("resolve_relative_path_from_cwd", function(assert)
		-- This test assumes we're in some working directory
		local result = path.posix.resolve("documents/file.txt")
		-- Absolute Windows paths will be parsed as relative posix paths because they don't start with /
		assert.eq(result.absolute, system.win32)
		-- The exact parts will depend on the current working directory
		-- But we can check that it ends with our relative path
		local endIndex = #result.parts
		assert.eq(result.parts[endIndex - 1], "documents")
		assert.eq(result.parts[endIndex], "file.txt")
	end)

	suite:case("resolve_multiple_paths", function(assert)
		local result = path.posix.resolve("/home", "user", "../admin", "documents")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "documents")
	end)

	suite:case("resolve_with_absolute_in_middle", function(assert)
		local result = path.posix.resolve("relative", "/absolute/path", "more")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "absolute")
		assert.eq(result.parts[2], "path")
		assert.eq(result.parts[3], "more")
	end)

	suite:case("resolve_no_arguments", function(assert)
		-- Should return normalized current working directory
		local result = path.posix.resolve()
		-- Absolute Windows paths will be parsed as relative posix paths because they don't start with /
		assert.eq(result.absolute, system.win32)
		-- Can't test exact parts since cwd varies
	end)

	suite:case("resolve_empty_strings", function(assert)
		local result = path.posix.resolve("", "", "/home/user")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 2)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "user")
	end)

	suite:case("resolve_with_dot_segments", function(assert)
		local result = path.posix.resolve("/home/user", "../admin/./documents")
		assert.eq(result.absolute, true)
		assert.eq(#result.parts, 3)
		assert.eq(result.parts[1], "home")
		assert.eq(result.parts[2], "admin")
		assert.eq(result.parts[3], "documents")
	end)
end)

test.run()
