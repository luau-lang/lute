local cli = require("@batteries/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local format = require("@self/format")
local files = require("./lib/files")

local HELP_MESSAGE = [[Usage: lute format [options] [files...]

Format Luau source files.

OPTIONS:
  -h, --help       Show this help message
  -c, --check      Check whether files are formatted
]]


local function main(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("check", "flag", { help = "Check formatting; exit 1 if any file is unformatted", aliases = { "c" } })
	args:add("files", "variadic", { help = "Files or directories to format (defaults to current directory)" })
	args:parse({ ... })

	if args:has("help") then
		print(HELP_MESSAGE)
		return
	end

	local check = args:has("check")

	local sourceFiles = files.getSourceFiles(args:variadics())
	if #sourceFiles == 0 then
		error("error: no source files provided")
	end

	local unformatted: { string } = {}

	for _, pathlike in sourceFiles do
		local source = fs.readFileToString(pathlike)
		local formatted = format.format(source)
		if formatted ~= source then
			if check then
				table.insert(unformatted, path.format(pathlike))
			else
				fs.writeStringToFile(pathlike, formatted)
			end
		end
	end

	if check and #unformatted > 0 then
		print(`\n{#unformatted} file(s) not formatted:\n{table.concat(unformatted, "\n")}`)
		process.exit(1)
	end
end

main(...)
