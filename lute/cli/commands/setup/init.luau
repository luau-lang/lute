local definitions = require("@self/generated/definitions")
local fs = require("@std/fs")
local process = require("@std/process")
local json = require("@std/json")

local BASE_PATH = ".lute/typedefs/0.1.0"
local BASE_PATH_PRETTY = `~/{BASE_PATH}`
local TEMPLATE_RC_FILE = {
	aliases = {
		lute = `{BASE_PATH_PRETTY}/lute`,
		std = `{BASE_PATH_PRETTY}/std`,
	},
}

local homeDir = process.homedir()
local cwd = process.cwd()
local args = { ... }

function mkdirdashp(home: string, subpath: string, noIncludeLast: boolean?)
	local subdir = home
	local parts = string.split(subpath, "/")
	local numParts = #parts

	for idx, part in parts do
		if noIncludeLast and (idx == numParts) then
			break
		end

		subdir = subdir .. "/" .. part
		if not fs.exists(subdir) then
			fs.mkdir(subdir)
		end
	end
end

-- TODO we're assuming the files are completely unmodified, but we really shouldn't do that.
print(`Writing definitions at {BASE_PATH_PRETTY}`)
mkdirdashp(homeDir, BASE_PATH)

for key, value in definitions :: { [string]: string } do
	local filePath = `{BASE_PATH}/{key}`
	mkdirdashp(homeDir, filePath, true)
	fs.writestringtofile(`{homeDir}/{filePath}`, value)
end

print(`Successfully wrote type definition files to {BASE_PATH_PRETTY}`)

if not table.find(args, "--with-luaurc") then
	return
end

local luauRcPath = `{cwd}/.luaurc`
local rcFile = nil
print(`Writing luaurc file at {luauRcPath}`)

if fs.exists(luauRcPath) then
	local contents = fs.readfiletostring(luauRcPath)
	rcFile = json.deserialize(contents) :: any

	rcFile.aliases = rcFile.aliases or {}
	for key, value in TEMPLATE_RC_FILE.aliases :: { [string]: string } do
		rcFile.aliases[key] = value
	end
else
	rcFile = TEMPLATE_RC_FILE
end
fs.writestringtofile(luauRcPath, json.serialize(rcFile, true))

print(`Successfully wrote luaurc file to {luauRcPath}`)
