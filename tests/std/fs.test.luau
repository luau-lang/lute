local failure = require("@std/test/failure")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local task = require("@lute/task")

local tmpdir = system.tmpdir()

test.suite("FsSuite", function(suite)
	suite:case("openReadWriteCloseAndStat", function(assert)
		local file = path.join(tmpdir, "file.txt")

		local h = fs.open(file, "w+")
		assert.that(fs.exists(file))
		fs.write(h, "abc")
		fs.close(h)

		local m = fs.metadata(file)
		assert.eq(m.size, 3)

		local hr = fs.open(file, "r")
		assert.eq(fs.read(hr), "abc")
		fs.close(hr)

		fs.remove(file)
	end)

	suite:case("writeStringAndReadfile", function(assert)
		local file = path.join(tmpdir, "hello.txt")
		fs.writeStringToFile(file, "hello lute")

		local contents = fs.readFileToString(file)
		assert.eq(contents, "hello lute")

		fs.remove(file)
	end)

	suite:case("existsAndTypeFileAndDir", function(assert)
		local file = path.join(tmpdir, "roblox.txt")
		fs.writeStringToFile(file, "roblox")

		assert.that(fs.exists(file))
		assert.eq(fs.type(file), "file")
		assert.that(fs.exists(tmpdir))
		assert.eq(fs.type(tmpdir), "dir")

		fs.remove(file)
	end)

	suite:case("mkdirListdirRmdir", function(assert)
		local dir = path.join(tmpdir, "subdir")
		if not fs.exists(dir) then
			fs.createDirectory(dir, { makeParents = true })
		end

		assert.that(fs.exists(dir))
		assert.eq(fs.type(dir), "dir")

		local entries = fs.listDirectory(tmpdir)
		local found = false
		for _, e in entries do
			if e.name == "subdir" then
				found = true
			end
		end
		assert.that(found)
		fs.removeDirectory(dir)
	end)

	suite:case("renameFile", function(assert)
		local src = path.join(tmpdir, "rename_src.txt")
		local dest = path.join(tmpdir, "rename_dest.txt")

		fs.writeStringToFile(src, "renamed content")

		fs.move(src, dest)

		assert.eq(fs.exists(src), false)
		assert.that(fs.exists(dest))
		assert.eq(fs.readFileToString(dest), "renamed content")

		fs.remove(dest)
	end)

	suite:case("moveDirectory", function(assert)
		local srcDir = path.join(tmpdir, "move_src_dir")
		local subDir = path.join(srcDir, "sub")
		local destDir = path.join(tmpdir, "move_dest_dir")

		fs.createDirectory(subDir, { makeParents = true })
		fs.writeStringToFile(path.join(srcDir, "a.txt"), "aaa")
		fs.writeStringToFile(path.join(subDir, "b.txt"), "bbb")

		fs.move(srcDir, destDir)

		assert.eq(fs.exists(srcDir), false)
		assert.that(fs.exists(destDir))
		assert.eq(fs.readFileToString(path.join(destDir, "a.txt")), "aaa")
		assert.eq(fs.readFileToString(path.join(destDir, "sub", "b.txt")), "bbb")

		fs.removeDirectory(destDir, { recursive = true })
	end)

	-- Exercises the EXDEV cross-device fallback for fs.move.
	-- Requires a cross-device mount to be set up in order to run.
	--
	-- In our CI, this is a tmpfs setup at `LUTE_CROSSDEV_TMPDIR`.
	-- The test is skipped when `LUTE_CROSSDEV_TMPDIR` is not set.
	suite:case("moveDirectoryAcrossDevices", function(assert)
		local crossdevTmp = process.env["LUTE_CROSSDEV_TMPDIR"]
		if crossdevTmp == nil then
			return
		end

		local srcDir = path.join(crossdevTmp, "lute_crossdev_src")
		local destDir = path.join(process.homedir(), ".lute-test-crossdev")

		if fs.exists(srcDir) then
			fs.removeDirectory(srcDir, { recursive = true })
		end

		if fs.exists(destDir) then
			fs.removeDirectory(destDir, { recursive = true })
		end

		local subDir = path.join(srcDir, "sub")
		fs.createDirectory(subDir, { makeParents = true })
		fs.writeStringToFile(path.join(srcDir, "a.txt"), "aaa")
		fs.writeStringToFile(path.join(subDir, "b.txt"), "bbb")

		local ok, err = pcall(function()
			fs.move(srcDir, destDir)

			assert.eq(fs.exists(srcDir), false)
			assert.that(fs.exists(destDir))
			assert.eq(fs.readFileToString(path.join(destDir, "a.txt")), "aaa")
			assert.eq(fs.readFileToString(path.join(destDir, "sub", "b.txt")), "bbb")
		end)

		if fs.exists(srcDir) then
			fs.removeDirectory(srcDir, { recursive = true })
		end

		if fs.exists(destDir) then
			fs.removeDirectory(destDir, { recursive = true })
		end

		if not ok then
			error(err)
		end
	end)

	suite:case("linkAndSymlinkAndCopy", function(assert)
		local srcfile = "src.txt"
		local src = path.join(tmpdir, srcfile)
		fs.writeStringToFile(src, "linkcontent")

		local dstlink = path.join(tmpdir, "dstlink")
		fs.link(src, dstlink)
		assert.eq(fs.readFileToString(dstlink), "linkcontent")
		fs.remove(dstlink)

		local dstcopy = path.join(tmpdir, "dstcopy.txt")
		fs.copy(src, dstcopy)
		assert.eq(fs.readFileToString(dstcopy), "linkcontent")
		fs.remove(dstcopy)

		local dstsymlink = path.join(tmpdir, "dstsymlink")
		fs.symbolicLink(srcfile, dstsymlink)
		assert.eq(fs.readFileToString(dstsymlink), "linkcontent")
		fs.remove(dstsymlink)

		fs.remove(src)
	end)

	suite:case("watchIteratorOnChange", function(assert)
		local watchedFileName = "watched.txt"
		local watched = path.join(tmpdir, watchedFileName)

		local watcher = fs.watch(tmpdir)

		fs.writeStringToFile(watched, "hi")

		-- Note: we had a timeout for this loop before, but it was leading to a flaky test where event = nil, so we're removing it.
		-- If this hangs indefinitely at, we'll see this test fail later and revisit.
		local start = os.clock()
		local event
		repeat
			event = watcher:next()
			if not event then
				task.wait(0.01)
			end
		until event

		print("Watch iterator time taken: " .. (os.clock() - start))
		if event == nil then
			failure.assertion("watcher event was nil")
			return
		end
		assert.that(event.change or event.rename)

		watcher:close()
		if fs.exists(watched) then
			fs.remove(watched)
		end
	end)

	suite:case("createDirectoryMakeparentsTrue", function(assert)
		local nestedDir = path.join(tmpdir, "nested", "directory")
		fs.createDirectory(nestedDir, { makeParents = true })
		assert.that(fs.exists(nestedDir))

		fs.removeDirectory(nestedDir)
		fs.removeDirectory(path.join(tmpdir, "nested"))
	end)

	suite:case("createDirectoryMakeparentsFalse", function(assert)
		local nestedDir = path.join(tmpdir, "this", "should", "not", "work")
		local success, err = pcall(function()
			fs.createDirectory(nestedDir, { makeParents = false })

			-- LUAUFIX: pcall's type is wrong, and we can mitigate that by returning nil from this function
			return nil
		end)
		assert.neq(success, true)
		assert.neq(err, nil)
	end)

	suite:case("createDirectoryNoOptions", function(assert)
		local nestedDir = path.join(tmpdir, "this", "should", "not", "work")
		local success, err = pcall(function()
			fs.createDirectory(nestedDir)

			-- LUAUFIX: pcall's type is wrong, and we can mitigate that by returning nil from this function
			return nil
		end)
		assert.neq(success, true)
		assert.neq(err, nil)
	end)

	suite:case("fsOpenOptionalMode", function(assert)
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

	suite:case("openWriteCreatesNewFile", function(assert)
		local file = path.join(tmpdir, "new_write_only.txt")

		-- Ensure file does not exist
		if fs.exists(file) then
			fs.remove(file)
		end

		local h = fs.open(file, "w")
		assert.that(fs.exists(file))
		fs.write(h, "hello")
		fs.close(h)

		assert.eq(fs.readFileToString(file), "hello")

		fs.remove(file)
	end)

	suite:case("removeDirectoryNonRecursive", function(assert)
		local dir = path.join(tmpdir, "empty_dir")
		fs.createDirectory(dir, { makeParents = true })
		assert.that(fs.exists(dir))

		fs.removeDirectory(dir)
		assert.eq(fs.exists(dir), false)
	end)

	suite:case("removeDirectoryRecursive", function(assert)
		local dir = path.join(tmpdir, "recursive_test")
		local subdir1 = path.join(dir, "subdir1")
		local subdir2 = path.join(dir, "subdir2")
		local nestedDir = path.join(subdir1, "nested")

		fs.createDirectory(nestedDir, { makeParents = true })
		fs.createDirectory(subdir2, { makeParents = true })

		local file1 = path.join(dir, "file1.txt")
		local file2 = path.join(subdir1, "file2.txt")
		local file3 = path.join(nestedDir, "file3.txt")

		fs.writeStringToFile(file1, "content1")
		fs.writeStringToFile(file2, "content2")
		fs.writeStringToFile(file3, "content3")

		assert.that(fs.exists(dir))
		assert.that(fs.exists(file1))
		assert.that(fs.exists(file2))
		assert.that(fs.exists(file3))

		fs.removeDirectory(dir, { recursive = true })

		assert.eq(fs.exists(dir), false)
		assert.eq(fs.exists(file1), false)
		assert.eq(fs.exists(file2), false)
		assert.eq(fs.exists(file3), false)
	end)

	suite:case("metadataDurationsHaveWorkingMetatable", function(assert)
		local file = path.join(tmpdir, "duration_meta_test.txt")
		fs.writeStringToFile(file, "test")

		local m = fs.metadata(file)

		-- duration methods should work without requiring @lute/time
		assert.that(m.created:toSeconds() > 0)
		assert.that(m.accessed:toSeconds() > 0)
		assert.that(m.modified:toSeconds() > 0)

		-- __tostring should produce "seconds.nanoseconds" format, not "userdata: 0x..."
		assert.that(tostring(m.created):match("^%d+%.%d+$"))

		-- arithmetic should work
		local sum = m.created + m.modified
		assert.that(sum:toSeconds() > 0)

		-- comparisons should work
		assert.that(m.created <= m.modified or m.modified <= m.created)

		fs.remove(file)
	end)

	suite:case("removeDirectoryRecursiveFalseWithContents", function(assert)
		local dir = path.join(tmpdir, "non_empty_dir")
		fs.createDirectory(dir, { makeParents = true })

		local file = path.join(dir, "file.txt")
		fs.writeStringToFile(file, "content")

		local success, err = pcall(function()
			fs.removeDirectory(dir, { recursive = false })
			-- FIXME(Luau): We should add an overload to `pcall` that allows
			-- passing a function that returns an empty pack.
			return nil
		end)

		assert.neq(success, true)
		assert.neq(err, nil)

		-- Cleanup
		fs.remove(file)
		fs.removeDirectory(dir)
	end)

	suite:case("walkDirectoryRecursive", function(assert)
		local baseDir = path.join(tmpdir, "walktest")
		local subDir = path.join(baseDir, "subdir")
		fs.createDirectory(subDir, { makeParents = true })

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
			assert.that(found)
		end

		fs.removeDirectory(baseDir, { recursive = true })
	end)
end)
