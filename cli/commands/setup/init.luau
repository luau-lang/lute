local generatedTypes = require("./generated-types")
local fs = require("@lute/fs")
local process = require("@lute/process")

local homedir = process.homedir()

if fs.type(homedir .. "/.lute") == "dir" then
	fs.rmdir(homedir .. "/.lute")
end

fs.mkdir(homedir .. "/.lute")
fs.mkdir(homedir .. "/.lute/typedefs")
fs.mkdir(homedir .. "/.lute/typedefs/0.1.0")

for key, value in generatedTypes :: { [string]: string } do
	fs.writestringtofile(homedir .. "/.lute/typedefs/0.1.0/" .. key, value)
end
