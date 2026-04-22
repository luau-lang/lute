local cli = require("@batteries/cli")
local definitions = require("@self/generated/definitions")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local json = require("@std/json")
local typedefs = require("./lib/typedefs")

local BASE_PATH = typedefs.TYPEDEFS_PATH
local BASE_PATH_PRETTY = typedefs.TYPEDEFS_RELATIVE_DIR
local TEMPLATE = typedefs.LUAURC_TEMPLATE

local args = cli.parser()
args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
args:add("with-luaurc", "flag", { help = "Also write a .luaurc file in the current directory" })
args:parse({ ... })

if args:has("help") then
	print("Usage: lute setup [options]")
	print([[
Install Lute type definitions to ~/.lute/typedefs/{version}.

OPTIONS:
  --with-luaurc     Also write a .luaurc file in the current directory
  -h, --help        Show this help message
]])
	return
end

-- TODO we're assuming the files are completely unmodified, but we really shouldn't do that.
print(`Writing definitions at {BASE_PATH_PRETTY}`)
if fs.exists(BASE_PATH) then
	fs.removeDirectory(BASE_PATH, { recursive = true })
end
fs.createDirectory(BASE_PATH, { makeParents = true })

for key, value in definitions :: { [string]: string } do
	local filePath = path.join(BASE_PATH, key)
	fs.createDirectory(path.dirname(filePath), { makeParents = true })
	fs.writeStringToFile(filePath, value)
end

local typedefsLuauRcPath = path.join(BASE_PATH, ".luaurc")

-- LUAUFIX. Without an annotation on typedefs.LUAURC_TEMPLATE, we arent able to figure out the type of TEMPLATE
-- If that table was declared in this file, this typechecks, but if it's in a different one, we'll get a type error here
fs.writeStringToFile(typedefsLuauRcPath, json.serialize(TEMPLATE, true))

print(`Successfully wrote type definition files to {BASE_PATH_PRETTY}`)

if not args:has("with-luaurc") then
	return
end

local luauRcPath = path.join(process.cwd(), ".luaurc")
local rcFile = nil
print(`Writing luaurc file at {luauRcPath}`)

if fs.exists(luauRcPath) then
	local contents = fs.readFileToString(luauRcPath)
	rcFile = json.deserialize(contents) :: any

	rcFile.aliases = rcFile.aliases or {}
	for key, value in TEMPLATE.aliases :: { [string]: string } do
		rcFile.aliases[key] = value
	end
else
	rcFile = TEMPLATE
end
fs.writeStringToFile(luauRcPath, json.serialize(rcFile, true))

print(`Successfully wrote luaurc file to {luauRcPath}`)
