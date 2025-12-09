local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")

local tmpdir = system.tmpdir()
local directory = path.join(tmpdir, "example_dir")

fs.createdirectory(directory, { makeparents = true })

if fs.exists(directory) and fs.type(directory) == "dir" then
	print("Directory successfully created")
else
	print("Failed to create directory")
end

fs.removedirectory(directory)

if not fs.exists(directory) then
	print("Directory successfully removed")
else
	print("Failed to remove directory")
end
