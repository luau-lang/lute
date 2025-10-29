local definitions = require("@self/generated/definitions")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local json = require("@std/json")

local BASE_PATH = ".lute/typedefs/0.1.0"
local BASE_PATH_PATHLIKE = path.parse(BASE_PATH)
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

-- TODO we're assuming the files are completely unmodified, but we really shouldn't do that.
print(`Writing definitions at {BASE_PATH_PRETTY}`)
fs.createdirectory(path.join(homeDir, BASE_PATH_PATHLIKE), { makeparents = true })

for key, value in definitions :: { [string]: string } do
	local filePathString = `{BASE_PATH}/{key}`
	local filePath = path.parse(filePathString)
	fs.createdirectory(path.dirname(filePath), { makeparents = true })
	fs.writestringtofile(filePath, value)
end

print(`Successfully wrote type definition files to {BASE_PATH_PRETTY}`)

if not table.find(args, "--with-luaurc") then
	return
end

local luauRcPath = `{cwd}/.luaurc`
local luauRcPathPathlike = path.parse(luauRcPath)
local rcFile = nil
print(`Writing luaurc file at {luauRcPath}`)

if fs.exists(luauRcPathPathlike) then
	local contents = fs.readfiletostring(luauRcPathPathlike)
	rcFile = json.deserialize(contents) :: any

	rcFile.aliases = rcFile.aliases or {}
	for key, value in TEMPLATE_RC_FILE.aliases :: { [string]: string } do
		rcFile.aliases[key] = value
	end
else
	rcFile = TEMPLATE_RC_FILE
end
fs.writestringtofile(luauRcPathPathlike, json.serialize(rcFile, true))

print(`Successfully wrote luaurc file to {luauRcPath}`)
