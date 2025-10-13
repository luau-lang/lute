local definitions = require("@self/generated/definitions")
local fs = require("@lute/fs")
local process = require("@lute/process")

local homedir = process.homedir()

function mkdirdashp(home: string, subpath: string)
	local subdir = home
	for _, part in string.split(subpath, "/") do
		subdir = subdir .. "/" .. part
		if not fs.exists(subdir) then
			fs.mkdir(subdir)
		end
	end
end

-- TODO we're assuming the files are completely unmodified, but we really shouldn't do that.
print("Found existing /.lute/ directory! Overwriting type definitions.")
mkdirdashp(homedir, ".lute/typedefs/0.1.0")

for key, value in definitions :: { [string]: string } do
	fs.writestringtofile(homedir .. "/.lute/typedefs/0.1.0/" .. key, value)
end

print("Successfully wrote type definition files to `~/.lute/typedefs/0.1.0/`")
