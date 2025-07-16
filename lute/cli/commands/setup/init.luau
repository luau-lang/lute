local definitions = require("@self/generated/definitions")
local fs = require("@lute/fs")
local process = require("@lute/process")

local homedir = process.homedir()

-- Already exists
-- TODO we're assuming the files are completely unmodified, but we really shouldn't do that.
print("Found existing /.lute/ directory! Overwriting type definitions.")
if not fs.exists(homedir .. "/.lute") then
	fs.mkdir(homedir .. "/.lute")
	fs.mkdir(homedir .. "/.lute/typedefs")
	fs.mkdir(homedir .. "/.lute/typedefs/0.1.0")
end

for key, value in definitions :: { [string]: string } do
	fs.writestringtofile(homedir .. "/.lute/typedefs/0.1.0/" .. key, value)
end

print("Successfully wrote type definition files to `~/.lute/typedefs/0.1.0/`")
