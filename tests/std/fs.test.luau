local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local tmpdir = system.tmpdir()

test.suite("FsSuite", function(suite)
	-- suite:case("open_read_write_close_and_stat", function(assert)
	-- 	local file = path.join(tmpdir, "file.txt")

	-- 	local h = fs.open(file, "w+")
	-- 	assert.eq(fs.exists(file), true)
	-- 	fs.write(h, "abc")
	-- 	fs.close(h)

	-- 	local m = fs.stat(file)
	-- 	assert.eq(m.size, 3)

	-- 	local hr = fs.open(file, "r")
	-- 	assert.eq(fs.read(hr), "abc")
	-- 	fs.close(hr)

	-- 	fs.remove(file)
	-- end)

	-- suite:case("writestring_and_readfile", function(assert)
	-- 	local file = path.join(tmpdir, "hello.txt")
	-- 	fs.writestringtofile(file, "hello lute")

	-- 	local contents = fs.readfiletostring(file)
	-- 	assert.eq(contents, "hello lute")

	-- 	fs.remove(file)
	-- end)

	-- suite:case("exists_and_type_file_and_dir", function(assert)
	-- 	local file = path.join(tmpdir, "roblox.txt")
	-- 	fs.writestringtofile(file, "roblox")

	-- 	assert.eq(fs.exists(file), true)
	-- 	assert.eq(fs.type(file), "file")
	-- 	assert.eq(fs.exists(tmpdir), true)
	-- 	assert.eq(fs.type(tmpdir), "dir")

	-- 	fs.remove(file)
	-- end)

	-- suite:case("mkdir_listdir_rmdir", function(assert)
	-- 	local dir = path.join(tmpdir, "subdir")
	-- 	if not fs.exists(dir) then
	-- 		fs.createdirectory(dir, { makeparents = true })
	-- 	end

	-- 	assert.eq(fs.exists(dir), true)
	-- 	assert.eq(fs.type(dir), "dir")

	-- 	local entries = fs.listdir(tmpdir)
	-- 	local found = false
	-- 	for _, e in entries do
	-- 		if e.name == "subdir" then
	-- 			found = true
	-- 		end
	-- 	end
	-- 	assert.eq(found, true)
	-- 	fs.rmdir(dir)
	-- end)

	-- suite:case("readasync_and_writestring", function(assert)
	-- 	local file = path.join(tmpdir, "async.txt")
	-- 	fs.writestringtofile(file, "async content")

	-- 	local got = fs.readasync(file)
	-- 	assert.eq(got, "async content")

	-- 	fs.remove(file)
	-- end)

	-- suite:case("link_and_symlink_and_copy", function(assert)
	-- 	local srcfile = "src.txt"
	-- 	local src = path.join(tmpdir, srcfile)
	-- 	fs.writestringtofile(src, "linkcontent")

	-- 	local dstlink = path.join(tmpdir, "dstlink")
	-- 	fs.link(src, dstlink)
	-- 	assert.eq(fs.readfiletostring(dstlink), "linkcontent")
	-- 	fs.remove(dstlink)

	-- 	local dstcopy = path.join(tmpdir, "dstcopy.txt")
	-- 	fs.copy(src, dstcopy)
	-- 	assert.eq(fs.readfiletostring(dstcopy), "linkcontent")
	-- 	fs.remove(dstcopy)

	-- 	local dstsymlink = path.join(tmpdir, "dstsymlink")
	-- 	fs.symlink(srcfile, dstsymlink)
	-- 	assert.eq(fs.readfiletostring(dstsymlink), "linkcontent")
	-- 	fs.remove(dstsymlink)

	-- 	fs.remove(src)
	-- end)

	-- suite:case("watch_callback_on_change", function(assert)
	-- 	local watched = path.join(tmpdir, "watched.txt")
	-- 	if fs.exists(watched) then
	-- 		fs.remove(watched)
	-- 	end

	-- 	local triggered = false
	-- 	local handle = fs.watch(tmpdir, function(filename, event)
	-- 		if tostring(filename):find("watched.txt") then
	-- 			triggered = true
	-- 		end
	-- 	end)

	-- 	fs.writestringtofile(watched, "x")

	-- 	local start = os.time()
	-- 	while not triggered and os.time() - start < 2 do
	-- 	end

	-- 	assert.eq(type(triggered) == "boolean", true)

	-- 	handle:close()
	-- 	if fs.exists(watched) then
	-- 		fs.remove(watched)
	-- 	end
	-- end)

	-- suite:case("createdirectory_makeparents_true", function(assert)
	-- 	local nestedDir = path.join(tmpdir, "nested", "directory")
	-- 	fs.createdirectory(nestedDir, { makeparents = true })
	-- 	assert.eq(fs.exists(nestedDir), true)

	-- 	fs.rmdir(nestedDir)
	-- 	fs.rmdir(path.join(tmpdir, "nested"))
	-- end)

	-- suite:case("createdirectory_makeparents_false", function(assert)
	-- 	local nestedDir = path.join(tmpdir, "this", "should", "not", "work")
	-- 	local success, err = pcall(function()
	-- 		fs.createdirectory(nestedDir, { makeparents = false })
	-- 	end)
	-- 	assert.neq(success, true)
	-- 	assert.neq(err, nil)
	-- end)

	-- suite:case("createdirectory_no_options", function(assert)
	-- 	local nestedDir = path.join(tmpdir, "this", "should", "not", "work")
	-- 	local success, err = pcall(function()
	-- 		fs.createdirectory(nestedDir)
	-- 	end)
	-- 	assert.neq(success, true)
	-- 	assert.neq(err, nil)
	-- end)

	-- suite:case("fs_open_optional_mode", function(assert)
	-- 	local file = path.join(tmpdir, "optional_mode.txt")

	-- 	local h1 = fs.open(file, "w+")
	-- 	fs.write(h1, "created file")
	-- 	fs.close(h1)

	-- 	local h2 = fs.open(file) -- with no mode specified, should default to "r"
	-- 	local contents = fs.read(h2)
	-- 	assert.eq(contents, "created file")
	-- 	fs.close(h2)

	-- 	fs.remove(file)
	-- end)

	suite:case("walk_directory_recursive", function(assert)
		-- local baseDir = path.join(tmpdir, "walktest")
		-- local subDir = path.join(baseDir, "subdir")
		-- fs.createdirectory(subDir, { makeparents = true })

		-- local file1 = path.join(baseDir, "file1.txt")
		-- local file2 = path.join(subDir, "file2.txt")
		-- fs.writestringtofile(file1, "file1")
		-- fs.writestringtofile(file2, "file2")

		-- print out the listdir for debugging
		-- print(baseDir)
		-- local entries = fs.listdir(baseDir)
		-- print(entries)
		-- print("Entries in baseDir:")
		-- for _, entry in entries do
		-- 	print(" - ", entry.name, entry.type)
		-- end

		-- print(subDir)
		-- local entries = fs.listdir(subDir)
		-- print("Entries in subDir:")
		-- for _, entry in entries do
		-- 	print(" - ", entry.name, entry.type)
		-- end

		-- print(fs.listdir("/var/folders/96/r83ggqdx0v975y4dhmsw2vt40000gn/T/walktest"))
		-- print(fs.listdir("/Users/annietang/git/roblox/lute/test1"))

		local foundFiles = {}
		for p in fs.walk("/Users/annietang/git/roblox/lute/test1", { recursive = true }) do
			print("Found path: ", tostring(p))
			table.insert(foundFiles, tostring(p))
		end

		-- print("All found files:")
		-- for _, f in foundFiles do
		-- 	print(" - ", f)
		-- end

		-- assert.eq(#foundFiles, 3) -- should find baseDir, file1, subDir, file2

		-- fs.remove(file1)
		-- fs.remove(file2)
		-- fs.rmdir(subDir)
		-- fs.rmdir(baseDir)
	end)
end)

test.run()
