local definitions = require("@self/generated/definitions")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local json = require("@std/json")

local TYPEDEFS_PATH = path.parse(".lute/typedefs/0.1.0")
local BASE_PATH = path.join(process.homedir(), TYPEDEFS_PATH)
local BASE_PATH_PRETTY = `~/{TYPEDEFS_PATH}`
local TEMPLATE_RC_FILE = {
	aliases = {
		lute = `{BASE_PATH_PRETTY}/lute`,
		std = `{BASE_PATH_PRETTY}/std`,
	},
}

local args = { ... }

-- TODO we're assuming the files are completely unmodified, but we really shouldn't do that.
print(`Writing definitions at {BASE_PATH_PRETTY}`)
if fs.exists(BASE_PATH) then
	fs.removedirectory(BASE_PATH, { recursive = true })
end
fs.createdirectory(BASE_PATH, { makeparents = true })

for key, value in definitions :: { [string]: string } do
	local filePath = path.join(BASE_PATH, key)
	fs.createdirectory(path.dirname(filePath), { makeparents = true })
	fs.writestringtofile(filePath, value)
end

print(`Successfully wrote type definition files to {BASE_PATH_PRETTY}`)

if not table.find(args, "--with-luaurc") then
	return
end

local luauRcPath = path.join(process.cwd(), ".luaurc")
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
