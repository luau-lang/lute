local io = require("@std/io")
local cli = require("@batteries/cli")
local dap = require("@self/dap")

local USAGE = "Usage: lute debug serve"

local function printHelp()
	print(USAGE)
	print([[
Starts the Lute debugger as a DAP server.

SUBCOMMANDS:
  serve                   Start a DAP debug adapter server over stdio

OPTIONS:
  -h, --help              Show this help message

EXAMPLES:
  lute debug serve
]])
end

local function main(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show help message", aliases = { "h" } })
	args:add("subcommand", "positional", { help = "serve", required = false })

	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	if args:get("subcommand") == "serve" then
		dap.dapLoop(io.input, io.write)
	else
		printHelp()
	end
end

main(...)
