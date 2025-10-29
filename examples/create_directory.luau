local fs = require("@std/fs")
local path = require("@std/path")

local directory = path.parse("example/new_directory/subdir")
fs.createdirectory(directory, { makeparents = true })
