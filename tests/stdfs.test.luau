local test = require("@std/test")
local path = require("@std/path")
local fs = require("@std/fs")
local tmpdir = "tmp"

test.suite("FsSuite", function(suite)
	suite:beforeall(function()
		if not fs.exists(tmpdir) then
			fs.mkdir(tmpdir)
		end
	end)

	suite:afterall(function()
		fs.rmdir(tmpdir)
	end)

	suite:case("open_read_write_close_and_stat", function(assert)
		local file = path.join(tmpdir, "file.txt")
		assert.eq(fs.exists(file), false)

		local h = fs.open(file, "w+")
		fs.write(h, "abc")
		fs.close(h)

		local m = fs.stat(file)
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
			fs.mkdir(dir)
		end

		assert.eq(fs.exists(dir), true)
		assert.eq(fs.type(dir), "dir")

		local entries = fs.listdir(tmpdir)
		local found = false
		for _, e in entries do
			if e.name == "subdir" then
				found = true
			end
		end
		assert.eq(found, true)
		fs.rmdir(dir)
	end)

	suite:case("readasync_and_writestring", function(assert)
		local file = path.join(tmpdir, "async.txt")
		fs.writestringtofile(file, "async content")

		local got = fs.readasync(file)
		assert.eq(got, "async content")

		fs.remove(file)
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
		fs.symlink(srcfile, dstsymlink)
		assert.eq(fs.readfiletostring(dstsymlink), "linkcontent")
		fs.remove(dstsymlink)

		fs.remove(src)
	end)

	suite:case("watch_callback_on_change", function(assert)
		local watched = path.join(tmpdir, "watched.txt")
		if fs.exists(watched) then
			fs.remove(watched)
		end

		local triggered = false
		local handle = fs.watch(tmpdir, function(filename, event)
			if tostring(filename):find("watched.txt") then
				triggered = true
			end
		end)

		fs.writestringtofile(watched, "x")

		local start = os.time()
		while not triggered and os.time() - start < 2 do
		end

		assert.eq(type(triggered) == "boolean", true)

		handle:close()
		if fs.exists(watched) then
			fs.remove(watched)
		end
	end)
end)

test.run()
