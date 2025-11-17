local fslib = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")

local tmpdir = system.tmpdir()
local baseDir = path.join(tmpdir, "walk_directory_example")

-- Setup: create a directory structure
if not fslib.exists(baseDir) then
	fslib.createdirectory(baseDir, { makeparents = true })
end

local subdirs = {
	"subdir1",
	"subdir2/nested1",
}

for _, subdir in subdirs do
	local fullPath = path.join(baseDir, subdir)
	fslib.createdirectory(fullPath, { makeparents = true })
end

local files = {
	"file1.txt",
	"subdir1/file2.txt",
	"subdir2/nested1/file3.txt",
}

for _, file in files do
	local fullPath = path.join(baseDir, file)
	fslib.writestringtofile(fullPath, "hello lute")
end

-- Walk the directory recursively
print("Walking directory:", baseDir)
local it = fslib.walk(baseDir, { recursive = true })
local walker = it()
while walker do
	print("Found:", walker)
	walker = it()
end

-- Cleanup: remove the created directory structure
fslib.removedirectory(baseDir, { recursive = true })
