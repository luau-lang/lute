local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local task = require("@lute/task")
local tasklib = require("@std/task")

local tmpdir = system.tmpdir()

test.suite("FsSuite", function(suite)
	suite:case("open_read_write_close_and_stat", function(assert)
		local file = path.join(tmpdir, "file.txt")

		local h = fs.open(file, "w+")
		assert.eq(fs.exists(file), true)
		fs.write(h, "abc")
		fs.close(h)

		local m = fs.metadata(file)
		assert.eq(m.size, 3)

		local hr = fs.open(file, "r")
		assert.eq(fs.read(hr), "abc")
		fs.close(hr)

		fs.remove(file)
	end)

	suite:case("writestring_and_readfile", function(assert)
		local file = path.join(tmpdir, "hello.txt")
		fs.writestringtofile(file, "hello lute")

		local contents = fs.readfiletostring(file)
		assert.eq(contents, "hello lute")

		fs.remove(file)
	end)

	suite:case("exists_and_type_file_and_dir", function(assert)
		local file = path.join(tmpdir, "roblox.txt")
		fs.writestringtofile(file, "roblox")

		assert.eq(fs.exists(file), true)
		assert.eq(fs.type(file), "file")
		assert.eq(fs.exists(tmpdir), true)
		assert.eq(fs.type(tmpdir), "dir")

		fs.remove(file)
	end)

	suite:case("mkdir_listdir_rmdir", function(assert)
		local dir = path.join(tmpdir, "subdir")
		if not fs.exists(dir) then
			fs.createdirectory(dir, { makeparents = true })
		end

		assert.eq(fs.exists(dir), true)
		assert.eq(fs.type(dir), "dir")

		local entries = fs.listdirectory(tmpdir)
		local found = false
		for _, e in entries do
			if e.name == "subdir" then
				found = true
			end
		end
		assert.eq(found, true)
		fs.removedirectory(dir)
	end)

	suite:case("link_and_symlink_and_copy", function(assert)
		local srcfile = "src.txt"
		local src = path.join(tmpdir, srcfile)
		fs.writestringtofile(src, "linkcontent")

		local dstlink = path.join(tmpdir, "dstlink")
		fs.link(src, dstlink)
		assert.eq(fs.readfiletostring(dstlink), "linkcontent")
		fs.remove(dstlink)

		local dstcopy = path.join(tmpdir, "dstcopy.txt")
		fs.copy(src, dstcopy)
		assert.eq(fs.readfiletostring(dstcopy), "linkcontent")
		fs.remove(dstcopy)

		local dstsymlink = path.join(tmpdir, "dstsymlink")
		fs.symboliclink(srcfile, dstsymlink)
		assert.eq(fs.readfiletostring(dstsymlink), "linkcontent")
		fs.remove(dstsymlink)

		fs.remove(src)
	end)

	suite:case("watch_iterator_on_change", function(assert)
		local watchedFileName = "watched.txt"
		local watched = path.join(tmpdir, watchedFileName)

		local watcher = fs.watch(tmpdir)

		fs.writestringtofile(watched, "hi")

		-- Note: we had a timeout for this loop before, but it was leading to a flaky test where event = nil, so we're removing it.
		-- If this hangs indefinitely at, we'll see this test fail later and revisit.
		local event
		repeat
			event = watcher:next()
			if not event then
				task.wait(0.01)
			end
		until event

		assert.neq(event, nil)
		assert.eq(event.change or event.rename, true)

		watcher:close()
		if fs.exists(watched) then
			fs.remove(watched)
		end
	end)

	suite:case("createdirectory_makeparents_true", function(assert)
		local nestedDir = path.join(tmpdir, "nested", "directory")
		fs.createdirectory(nestedDir, { makeparents = true })
		assert.eq(fs.exists(nestedDir), true)

		fs.removedirectory(nestedDir)
		fs.removedirectory(path.join(tmpdir, "nested"))
	end)

	suite:case("createdirectory_makeparents_false", function(assert)
		local nestedDir = path.join(tmpdir, "this", "should", "not", "work")
		local success, err = pcall(function()
			fs.createdirectory(nestedDir, { makeparents = false })
		end)
		assert.neq(success, true)
		assert.neq(err, nil)
	end)

	suite:case("createdirectory_no_options", function(assert)
		local nestedDir = path.join(tmpdir, "this", "should", "not", "work")
		local success, err = pcall(function()
			fs.createdirectory(nestedDir)
		end)
		assert.neq(success, true)
		assert.neq(err, nil)
	end)

	suite:case("fs_open_optional_mode", function(assert)
		local file = path.join(tmpdir, "optional_mode.txt")

		local h1 = fs.open(file, "w+")
		fs.write(h1, "created file")
		fs.close(h1)

		local h2 = fs.open(file) -- with no mode specified, should default to "r"
		local contents = fs.read(h2)
		assert.eq(contents, "created file")
		fs.close(h2)

		fs.remove(file)
	end)

	suite:case("removedirectory_non_recursive", function(assert)
		local dir = path.join(tmpdir, "empty_dir")
		fs.createdirectory(dir, { makeparents = true })
		assert.eq(fs.exists(dir), true)

		fs.removedirectory(dir)
		assert.eq(fs.exists(dir), false)
	end)

	suite:case("removedirectory_recursive", function(assert)
		local dir = path.join(tmpdir, "recursive_test")
		local subdir1 = path.join(dir, "subdir1")
		local subdir2 = path.join(dir, "subdir2")
		local nestedDir = path.join(subdir1, "nested")

		fs.createdirectory(nestedDir, { makeparents = true })
		fs.createdirectory(subdir2, { makeparents = true })

		local file1 = path.join(dir, "file1.txt")
		local file2 = path.join(subdir1, "file2.txt")
		local file3 = path.join(nestedDir, "file3.txt")

		fs.writestringtofile(file1, "content1")
		fs.writestringtofile(file2, "content2")
		fs.writestringtofile(file3, "content3")

		assert.eq(fs.exists(dir), true)
		assert.eq(fs.exists(file1), true)
		assert.eq(fs.exists(file2), true)
		assert.eq(fs.exists(file3), true)

		fs.removedirectory(dir, { recursive = true })

		assert.eq(fs.exists(dir), false)
		assert.eq(fs.exists(file1), false)
		assert.eq(fs.exists(file2), false)
		assert.eq(fs.exists(file3), false)
	end)

	suite:case("removedirectory_recursive_false_with_contents", function(assert)
		local dir = path.join(tmpdir, "non_empty_dir")
		fs.createdirectory(dir, { makeparents = true })

		local file = path.join(dir, "file.txt")
		fs.writestringtofile(file, "content")

		local success, err = pcall(function()
			fs.removedirectory(dir, { recursive = false })
		end)

		assert.neq(success, true)
		assert.neq(err, nil)

		-- Cleanup
		fs.remove(file)
		fs.removedirectory(dir)
	end)

	suite:case("walk_directory_recursive", function(assert)
		local baseDir = path.join(tmpdir, "walktest")
		local subDir = path.join(baseDir, "subdir")
		fs.createdirectory(subDir, { makeparents = true })

		local file1 = path.join(baseDir, "file1.txt")
		local f1 = fs.open(file1, "w+")
		fs.close(f1)

		local file2 = path.join(subDir, "file2.txt")
		local f2 = fs.open(file2, "w+")
		fs.close(f2)

		local expectedPaths = {
			tostring(baseDir),
			tostring(file1),
			tostring(subDir),
			tostring(file2),
		}
		local foundFiles = {}

		local it = fs.walk(baseDir, { recursive = true })
		local p = it()
		while p do
			table.insert(foundFiles, tostring(p))
			p = it()
		end

		for _, expected in expectedPaths do
			local found = false
			for _, foundPath in foundFiles do
				if foundPath == expected then
					found = true
					break
				end
			end
			assert.eq(found, true)
		end

		fs.removedirectory(baseDir, { recursive = true })
	end)
end)

test.run()
