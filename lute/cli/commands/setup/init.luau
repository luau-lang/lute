local definitions = require("@self/generated/definitions")
local fs = require("@lute/fs")
local process = require("@lute/process")

local homedir = process.homedir()

fs.mkdir(homedir .. "/.lute")
fs.mkdir(homedir .. "/.lute/typedefs")
fs.mkdir(homedir .. "/.lute/typedefs/0.1.0")

for key, value in definitions :: { [string]: string } do
	fs.writestringtofile(homedir .. "/.lute/typedefs/0.1.0/" .. key, value)
end
