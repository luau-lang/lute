local process = require("@std/process")

local install = require("@self/loom-core/src/commands/install")
local authenticate = require("@self/loom-core/src/commands/authenticate")

local USAGE = "Usage: lute pkg <command>"

local function printHelp()
	print(USAGE)
	print([[

Loom package manager for Luau projects.

COMMANDS:
  install                  Install dependencies from loom.config.luau
  auth <action> [options]  Manage credentials in the OS-native credential store
                           (actions: add, remove, migrate)

Use --help with any command for more information.
]])
end

local function main(...: string)
	local args = { ... }

	if #args == 0 or args[1] == "--help" or args[1] == "-h" then
		printHelp()
		return
	end

	local command = args[1]

	if command == "install" then
		install(table.unpack(args, 2))
	elseif command == "auth" then
		authenticate(table.unpack(args, 2))
	else
		print(`Unknown command: {command}\n`)
		printHelp()
		process.exit(1)
	end
end

main(...)
