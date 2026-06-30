local process = require("@std/process")

local install = require("@self/install")
local update = require("@self/update")
local uninstall = require("@self/uninstall")

local HELP_STRING = [[Usage: lute self <command> [options]

Manage the host lute installation in ~/.lute.

COMMANDS:
  install      Install the running lute into ~/.lute/bin and update PATH
  update       Update the host lute to the latest release
  uninstall    Remove the host lute installation
  help         Show this help message

Use --help with any command for more information.
]]

local function main(...: string)
	local args = { ... }
	local command = args[1]

	if command == nil or command == "help" or command == "--help" or command == "-h" then
		print(HELP_STRING)
		return
	end

	if command == "install" then
		install(table.unpack(args, 2))
	elseif command == "update" then
		update(table.unpack(args, 2))
	elseif command == "uninstall" then
		uninstall(table.unpack(args, 2))
	else
		print(`Unknown command: {command}\n`)
		print(HELP_STRING)
		process.exit(1)
	end
end

main(...)
