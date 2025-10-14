local test = require("@std/test")
local path = require("@std/path")

test.suite("PathParseSuite", function()
    test.case("parse_unix_absolute_path", function()
        local result = path.parse("/home/user/documents/file.txt")
        test.assert.eq(result.isAbsolute, true)
        test.assert.eq(result.isUNCPath, false)
        test.assert.eq(result.driveLetter, nil)
        test.assert.eq(#result.parts, 4)
        test.assert.eq(result.parts[1], "home")
        test.assert.eq(result.parts[2], "user")
        test.assert.eq(result.parts[3], "documents")
        test.assert.eq(result.parts[4], "file.txt")
    end)

    test.case("parse_unix_relative_path", function()
        local result = path.parse("documents/file.txt")
        test.assert.eq(result.isAbsolute, false)
        test.assert.eq(result.isUNCPath, false)
        test.assert.eq(result.driveLetter, nil)
        test.assert.eq(#result.parts, 2)
        test.assert.eq(result.parts[1], "documents")
        test.assert.eq(result.parts[2], "file.txt")
    end)

    test.case("parse_windows_absolute_path", function()
        local result = path.parse("C:\\Users\\username\\Documents\\file.txt")
        test.assert.eq(result.isAbsolute, true)
        test.assert.eq(result.isUNCPath, false)
        test.assert.eq(result.driveLetter, "C")
        test.assert.eq(#result.parts, 4)
        test.assert.eq(result.parts[1], "Users")
        test.assert.eq(result.parts[2], "username")
        test.assert.eq(result.parts[3], "Documents")
        test.assert.eq(result.parts[4], "file.txt")
    end)

    test.case("parse_windows_unc_path", function()
        local result = path.parse("\\\\server\\share\\folder\\file.txt")
        test.assert.eq(result.isAbsolute, true)
        test.assert.eq(result.isUNCPath, true)
        test.assert.eq(result.driveLetter, nil)
        test.assert.eq(#result.parts, 4)
        test.assert.eq(result.parts[1], "server")
        test.assert.eq(result.parts[2], "share")
        test.assert.eq(result.parts[3], "folder")
        test.assert.eq(result.parts[4], "file.txt")
    end)

    test.case("parse_empty_string", function()
        local result = path.parse("")
        test.assert.eq(result.isAbsolute, false)
        test.assert.eq(result.isUNCPath, false)
        test.assert.eq(result.driveLetter, nil)
        test.assert.eq(#result.parts, 0)
    end)

    test.case("parse_root_path", function()
        local result = path.parse("/")
        test.assert.eq(result.isAbsolute, true)
        test.assert.eq(result.isUNCPath, false)
        test.assert.eq(result.driveLetter, nil)
        test.assert.eq(#result.parts, 0)
    end)

    test.case("parse_single_file", function()
        local result = path.parse("file.txt")
        test.assert.eq(result.isAbsolute, false)
        test.assert.eq(result.isUNCPath, false)
        test.assert.eq(result.driveLetter, nil)
        test.assert.eq(#result.parts, 1)
        test.assert.eq(result.parts[1], "file.txt")
    end)

    test.case("parse_pathobj_returns_same", function()
        local originalPath : path.PathObj = {
            parts = {"folder", "file.txt"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.parse(originalPath)
        test.assert.eq(result, originalPath)
    end)

    test.case("parse_mixed_separators", function()
        local result = path.parse("/home/user\\documents/file.txt")
        test.assert.eq(result.isAbsolute, false) -- This is a relative path on Windows
        test.assert.eq(#result.parts, 4)
        test.assert.eq(result.parts[1], "home")
        test.assert.eq(result.parts[2], "user")
        test.assert.eq(result.parts[3], "documents")
        test.assert.eq(result.parts[4], "file.txt")
    end)

    test.case("parse_windows_relative_with_drive", function()
        local result = path.parse("C:Documents\\file.txt")
        test.assert.eq(result.isAbsolute, false)
        test.assert.eq(result.isUNCPath, false)
        test.assert.eq(result.driveLetter, "C")
        test.assert.eq(#result.parts, 2)
        test.assert.eq(result.parts[1], "Documents")
        test.assert.eq(result.parts[2], "file.txt")
    end)
end)

test.suite("PathBasenameSuite", function()
    test.case("basename_unix_absolute_path", function()
        local result = path.basename("/home/user/documents/file.txt")
        test.assert.eq(result, "file.txt")
    end)

    test.case("basename_unix_relative_path", function()
        local result = path.basename("documents/file.txt")
        test.assert.eq(result, "file.txt")
    end)

    test.case("basename_windows_absolute_path", function()
        local result = path.basename("C:\\Users\\username\\Documents\\file.txt")
        test.assert.eq(result, "file.txt")
    end)

    test.case("basename_windows_unc_path", function()
        local result = path.basename("\\\\server\\share\\folder\\file.txt")
        test.assert.eq(result, "file.txt")
    end)

    test.case("basename_single_file", function()
        local result = path.basename("file.txt")
        test.assert.eq(result, "file.txt")
    end)

    test.case("basename_directory_no_extension", function()
        local result = path.basename("/home/user/documents")
        test.assert.eq(result, "documents")
    end)

    test.case("basename_empty_path", function()
        local result = path.basename("")
        test.assert.eq(result, nil)
    end)

    test.case("basename_root_path", function()
        local result = path.basename("/")
        test.assert.eq(result, nil)
    end)

    test.case("basename_pathobj", function()
        local pathObj : path.PathObj = {
            parts = {"folder", "subfolder", "file.txt"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.basename(pathObj)
        test.assert.eq(result, "file.txt")
    end)

    test.case("basename_mixed_separators", function()
        local result = path.basename("/home/user\\documents/file.txt")
        test.assert.eq(result, "file.txt")
    end)
end)

test.suite("PathFormatSuite", function()
    test.case("format_unix_absolute_path", function()
        local pathObj : path.PathObj = {
            parts = {"home", "user", "documents", "file.txt"},
            isAbsolute = true,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "/home/user/documents/file.txt")
    end)

    test.case("format_unix_relative_path", function()
        local pathObj : path.PathObj = {
            parts = {"documents", "file.txt"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "documents/file.txt")
    end)

    test.case("format_windows_absolute_path", function()
        local pathObj : path.PathObj = {
            parts = {"Users", "username", "Documents", "file.txt"},
            isAbsolute = true,
            isUNCPath = false,
            driveLetter = "C",
            isWindows = true
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "C:\\Users\\username\\Documents\\file.txt")
    end)

    test.case("format_windows_relative_with_drive", function()
        local pathObj : path.PathObj = {
            parts = {"Documents", "file.txt"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = "C",
            isWindows = true
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "C:Documents\\file.txt")
    end)

    test.case("format_windows_unc_path", function()
        local pathObj : path.PathObj = {
            parts = {"server", "share", "folder", "file.txt"},
            isAbsolute = true,
            isUNCPath = true,
            driveLetter = nil,
            isWindows = true
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "\\\\server\\share\\folder\\file.txt")
    end)

    test.case("format_empty_relative_path", function()
        local pathObj : path.PathObj = {
            parts = {},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.format(pathObj)
        test.assert.eq(result, ".")
    end)

    test.case("format_empty_relative_windows_path", function()
        local pathObj : path.PathObj = {
            parts = {},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = true
        }
        local result = path.format(pathObj)
        test.assert.eq(result, ".")
    end)

    test.case("format_root_path", function()
        local pathObj : path.PathObj = {
            parts = {},
            isAbsolute = true,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "/")
    end)

    test.case("format_empty_relative_path_with_drive", function()
        local pathObj : path.PathObj = {
            parts = {},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = "C",
            isWindows = true
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "C:")
    end)

    test.case("format_root_path_with_drive", function()
        local pathObj : path.PathObj = {
            parts = {},
            isAbsolute = true,
            isUNCPath = false,
            driveLetter = "C",
            isWindows = true
        }
        local result = path.format(pathObj)
        test.assert.eq(result, "C:\\")
    end)

    test.case("format_string_returns_same", function()
        local result = path.format("/home/user/file.txt")
        test.assert.eq(result, "/home/user/file.txt")
    end)
end)

test.suite("PathDirnameSuite", function()
    test.case("dirname_unix_absolute_path", function()
        local result = path.dirname("/home/user/documents/file.txt")
        test.assert.eq(result, "/home/user/documents")
    end)

    test.case("dirname_unix_relative_path", function()
        local result = path.dirname("documents/file.txt")
        test.assert.eq(result, "documents")
    end)

    test.case("dirname_windows_absolute_path", function()
        local result = path.dirname("C:\\Users\\username\\Documents\\file.txt")
        test.assert.eq(result, "C:\\Users\\username\\Documents")
    end)

    test.case("dirname_windows_unc_path", function()
        local result = path.dirname("\\\\server\\share\\folder\\file.txt")
        test.assert.eq(result, "\\\\server\\share\\folder")
    end)

    test.case("dirname_single_file", function()
        local result = path.dirname("file.txt")
        test.assert.eq(result, ".")
    end)

    test.case("dirname_nested_directory", function()
        local result = path.dirname("/home/user/documents/subfolder")
        test.assert.eq(result, "/home/user/documents")
    end)

    test.case("dirname_empty_path", function()
        local result = path.dirname("")
        test.assert.eq(result, ".")
    end)

    test.case("dirname_root_path", function()
        local result = path.dirname("/")
        test.assert.eq(result, "/")
    end)

    test.case("dirname_windows_root", function()
        local result = path.dirname("C:\\")
        test.assert.eq(result, "C:\\")
    end)

    test.case("dirname_pathobj", function()
        local pathObj : path.PathObj = {
            parts = {"folder", "subfolder", "file.txt"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.dirname(pathObj)
        test.assert.eq(result, "folder/subfolder")
    end)

    test.case("dirname_windows_relative_with_drive", function()
        local result = path.dirname("C:Documents\\file.txt")
        test.assert.eq(result, "C:Documents")
    end)
end)

test.suite("PathExtnameSuite", function()
    test.case("extname_simple_extension", function()
        local result = path.extname("/home/user/file.txt")
        test.assert.eq(result, ".txt")
    end)

    test.case("extname_multiple_dots", function()
        local result = path.extname("/home/user/archive.tar.gz")
        test.assert.eq(result, ".gz")
    end)

    test.case("extname_no_extension", function()
        local result = path.extname("/home/user/README")
        test.assert.eq(result, "")
    end)

    test.case("extname_hidden_file_with_extension", function()
        local result = path.extname("/home/user/.bashrc")
        test.assert.eq(result, "")
    end)

    test.case("extname_hidden_file_with_real_extension", function()
        local result = path.extname("/home/user/.config.json")
        test.assert.eq(result, ".json")
    end)

    test.case("extname_windows_path", function()
        local result = path.extname("C:\\Users\\username\\document.docx")
        test.assert.eq(result, ".docx")
    end)

    test.case("extname_directory_path", function()
        local result = path.extname("/home/user/documents")
        test.assert.eq(result, "")
    end)

    test.case("extname_empty_path", function()
        local result = path.extname("")
        test.assert.eq(result, "")
    end)

    test.case("extname_root_path", function()
        local result = path.extname("/")
        test.assert.eq(result, "")
    end)

    test.case("extname_pathobj", function()
        local pathObj : path.PathObj = {
            parts = {"folder", "file.pdf"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.extname(pathObj)
        test.assert.eq(result, ".pdf")
    end)

    test.case("extname_dot_only", function()
        local result = path.extname("/home/user/file.")
        test.assert.eq(result, ".")
    end)

    test.case("extname_filename_is_dot", function()
        local result = path.extname("/home/user/.")
        test.assert.eq(result, "")
    end)

    test.case("extname_filename_is_dotdot", function()
        local result = path.extname("/home/user/..")
        test.assert.eq(result, "")
    end)
end)

test.suite("PathIsAbsoluteSuite", function()
    test.case("isAbsolute_unix_absolute_path", function()
        local result = path.isAbsolute("/home/user/documents/file.txt")
        test.assert.eq(result, true)
    end)

    test.case("isAbsolute_unix_relative_path", function()
        local result = path.isAbsolute("documents/file.txt")
        test.assert.eq(result, false)
    end)

    test.case("isAbsolute_windows_absolute_path", function()
        local result = path.isAbsolute("C:\\Users\\username\\Documents\\file.txt")
        test.assert.eq(result, true)
    end)

    test.case("isAbsolute_windows_relative_path", function()
        local result = path.isAbsolute("Documents\\file.txt")
        test.assert.eq(result, false)
    end)

    test.case("isAbsolute_windows_relative_with_drive", function()
        local result = path.isAbsolute("C:Documents\\file.txt")
        test.assert.eq(result, false)
    end)

    test.case("isAbsolute_windows_unc_path", function()
        local result = path.isAbsolute("\\\\server\\share\\folder\\file.txt")
        test.assert.eq(result, true)
    end)

    test.case("isAbsolute_root_path", function()
        local result = path.isAbsolute("/")
        test.assert.eq(result, true)
    end)

    test.case("isAbsolute_empty_path", function()
        local result = path.isAbsolute("")
        test.assert.eq(result, false)
    end)

    test.case("isAbsolute_pathobj_absolute", function()
        local pathObj : path.PathObj = {
            parts = {"home", "user", "file.txt"},
            isAbsolute = true,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.isAbsolute(pathObj)
        test.assert.eq(result, true)
    end)

    test.case("isAbsolute_pathobj_relative", function()
        local pathObj : path.PathObj = {
            parts = {"folder", "file.txt"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil,
            isWindows = false
        }
        local result = path.isAbsolute(pathObj)
        test.assert.eq(result, false)
    end)
end)

test.run()
