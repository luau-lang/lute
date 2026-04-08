local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local scriptPath = path.resolve(process.cwd(), process.args[1])

local metadata = fs.metadata(scriptPath)
local created = metadata.created

print(tostring(created))
