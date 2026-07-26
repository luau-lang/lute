local cli = require("@batteries/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local files = require("./lib/files")

local HELP_MESSAGE = [[Usage: lute format [options] [files...]

Format Luau source files.

OPTIONS:
  -h, --help       Show this help message
  -v, --verbose    Enable verbose output
  -c, --check      Check whether files are formatted
]]

local function formatSource(source: string): string
	-- stub format function
	return source
end

local function main(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("verbose", "flag", { help = "Enable verbose output", aliases = { "v" } })
	args:add("check", "flag", { help = "Check formatting; exit 1 if any file is unformatted", aliases = { "c" } })
	args:add("files", "variadic", { help = "Files or directories to format (defaults to current directory)" })
	args:parse({ ... })

	if args:has("help") then
		print(HELP_MESSAGE)
		return
	end

	local check = args:has("check")
	local verbose = args:has("verbose")

	local inputPaths = args:variadics()
	if #inputPaths == 0 then
		inputPaths = { path.format(process.cwd()) }
	end

	local sourceFiles = files.getSourceFiles(inputPaths, verbose)
	if #sourceFiles == 0 then
		print("Error: no Luau files found")
		process.exit(1)
	end

	local failed: { string } = {}
	local unformatted: { string } = {}

	for _, pathlike in sourceFiles do
		local target = path.format(pathlike)

		local read, source = pcall(fs.readFileToString, pathlike)
		if not read then
			table.insert(failed, `{target}: {source}`)
			continue
		end

		local ok, formatted = pcall(formatSource, source :: string)
		if not ok then
			table.insert(failed, `{target}: {formatted}`)
			continue
		end

		if formatted ~= source then
			table.insert(unformatted, target)
			if not check then
				fs.writeStringToFile(pathlike, formatted)
				if verbose then
					print(`Formatted {target}`)
				end
			end
		end
	end

	if verbose then
		if check then
			if #unformatted == 0 then
				print(`All {#sourceFiles} file(s) are formatted.`)
			else
				print(`Checked {#sourceFiles} file(s)`)
				print(`{#unformatted} file(s) were not formatted`)
			end
		else
			print(`Formatted {#unformatted} of {#sourceFiles} file(s).`)
		end
	end

	if check and #unformatted > 0 then
		print(`\n{#unformatted} file(s) not formatted:\n{table.concat(unformatted, "\n")}`)
	end

	if #failed > 0 then
		print(`\n{#failed} file(s) could not be formatted:\n{table.concat(failed, "\n")}`)
	end

	if #failed > 0 or (check and #unformatted > 0) then
		process.exit(1)
	end
end

main(...)
