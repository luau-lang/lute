local io = require("@std/io")
local cli = require("@batteries/cli")
local dap = require("@self/dap")

local function printHelp(args: cli.Parser)
	print(args:usage("lute debug"))
	print("\nStarts the Lute debugger as a DAP server.\n")
	print(args:help())
	print([[

SUBCOMMANDS:
  serve                   Start a DAP debug adapter server over stdio

EXAMPLES:
  lute debug serve
]])
end

local function main(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show help message", aliases = { "h" } })
	args:add("subcommand", "positional", { help = "Subcommand to run (serve)", required = false })

	args:parse({ ... })

	if args:has("help") then
		printHelp(args)
		return
	end

	if args:get("subcommand") == "serve" then
		dap.dapLoop(io.input, io.write)
	else
		printHelp(args)
	end
end

main(...)
