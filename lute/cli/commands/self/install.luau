local cli = require("@batteries/cli")
local fs = require("@std/fs")
local io = require("@std/io")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")

local paths = require("./paths")
local pathenv = require("./pathenv")

local HELP_STRING = [[
Install the running lute as the host toolchain in ~/.lute/bin.

OPTIONS:
  --force            Continue without prompting
  --no-modify-path   Do not add lute to PATH
  -h, --help         Show this help message
]]

local function confirm(prompt: string): boolean
	local line = io.input(`{prompt} [Y/n] `)
	local answer = string.lower(stringext.trim(line))
	return answer == "" or answer == "y" or answer == "yes"
end

return function(...: string)
	local args = cli.parser()
	args:add("force", "flag", { help = "Continue without prompting" })
	args:add("no-modify-path", "flag", { help = "Do not add lute to PATH" })
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:parse({ ... })

	if args:has("help") then
		print("Usage: lute self install [options...]\n")
		print(HELP_STRING)
		return
	end

	local destination = paths.exePath("lute")
	local source = path.format(path.normalize(process.execPath()))

	if fs.exists(destination) and source ~= destination then
		if not args:has("force") and not confirm(`Replace existing lute at {destination}?`) then
			print("Aborted installation.")
			return
		end
	end

	fs.createDirectory(paths.binPath(), { makeParents = true })

	if source == destination then
		print(`lute is already installed at {destination}`)
	else
		fs.copy(source, destination)
		print(`Installed lute to {destination}`)
	end

	if not args:has("no-modify-path") then
		pathenv.ensureOnPath()
	end

	local setup = process.run({ destination, "setup" }, { stdio = "inherit" })
	if not setup.ok then
		print("warning: `lute setup` failed; run it manually to install type definitions")
	end
end
