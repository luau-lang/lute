local cli = require("@batteries/cli")
local fs = require("@std/fs")
local io = require("@std/io")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")
local system = require("@std/system")

local paths = require("./paths")
local pathenv = require("./pathenv")

local HELP_STRING = [[
Remove the host lute binary and strip PATH entries.

OPTIONS:
  --remove-data      Also remove cached type definitions and other data
  --force            Remove without prompting
  -h, --help         Show this help message
]]

local function confirm(prompt: string): boolean
	local line = io.input(`{prompt} [y/N] `)
	local answer = string.lower(stringext.trim(line))
	return answer == "y" or answer == "yes"
end

return function(...: string)
	local args = cli.parser()
	args:add("remove-data", "flag", { help = "Remove all data under ~/.lute" })
	args:add("force", "flag", { help = "Remove without confirming" })
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:parse({ ... })

	if args:has("help") then
		print("Usage: lute self uninstall [options]\n")
		print(HELP_STRING)
		return
	end

	local target = if args:has("remove-data") then paths.lutePath() else paths.binPath()

	if not fs.exists(target) then
		print(`Nothing to remove at {target}`)
	else
		if system.win32 and paths.exePath("lute") == path.format(path.normalize(process.execPath())) then
			error("Windows cannot remove a running executable. Run this command from another copy of lute.", 0)
		end
		if not args:has("force") and not confirm(`Remove {target}?`) then
			print("Aborted uninstallation.")
			return
		end
		fs.removeDirectory(target, { recursive = true })
		print(`Removed {target}`)
	end

	local affected = pathenv.removeFromPath()
	if #affected > 0 then
		print("Removed lute PATH entries from:")
		for _, profile in affected do
			print(`  {profile}`)
		end
		if not system.win32 then
			print("Restart your shell or re-source the profile to pick up the change.")
		end
	end
end
