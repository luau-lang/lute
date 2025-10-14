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
        local originalPath = {
            parts = {"folder", "file.txt"},
            isAbsolute = false,
            isUNCPath = false,
            driveLetter = nil
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
            driveLetter = nil
        }
        local result = path.basename(pathObj)
        test.assert.eq(result, "file.txt")
    end)

    test.case("basename_mixed_separators", function()
        local result = path.basename("/home/user\\documents/file.txt")
        test.assert.eq(result, "file.txt")
    end)
end)

test.run()
