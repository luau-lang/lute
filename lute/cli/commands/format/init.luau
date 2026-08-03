local cli = require("@batteries/cli")
local format = require("@self/format")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local files = require("./lib/files")

local DESCRIPTION = [[

Format Luau source files. Experimental: formatting is still under development, and its output will change.
]]

local function main(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("verbose", "flag", { help = "Enable verbose output", aliases = { "v" } })
	args:add("check", "flag", { help = "Check formatting; exit 1 if any file is unformatted", aliases = { "c" } })
	args:add("files", "variadic", { help = "Files or directories to format (defaults to current directory)" })
	args:parse({ ... })

	if args:has("help") then
		print(args:usage("lute format"))
		print(DESCRIPTION)
		args:help()
		return
	end

	local check = args:has("check")
	local verbose = args:has("verbose")

	local inputPaths = args:variadics()
	if #inputPaths == 0 then
		inputPaths = table.freeze({ "." })
	end

	local sourceFiles = files.getSourceFiles(inputPaths, verbose)
	if #sourceFiles == 0 then
		print("Error: no Luau files found")
		process.exit(1)
	end

	local failed: { string } = {}
	local needsFormatting: { string } = {}

	for _, sourcePath in sourceFiles do
		local target = path.format(sourcePath)

		if verbose then
			print(`Trying to format {target}`)
		end

		local read, source = pcall(fs.readFileToString, sourcePath)
		if not read then
			table.insert(failed, `{target}: {source}`)
			continue
		end

		local ok, formatted = pcall(format.formatSource, source)
		if not ok then
			table.insert(failed, `{target}: {formatted}`)
			continue
		end

		if formatted ~= source then
			table.insert(needsFormatting, target)
			if not check then
				fs.writeStringToFile(sourcePath, formatted)
				if verbose then
					print(`Formatted {target}`)
				end
			end
		end
	end

	if verbose then
		if check then
			print(`Checked {#sourceFiles} file(s).`)
			if #needsFormatting == 0 then
				print(`All {#sourceFiles} file(s) were formatted properly.`)
			else
				print(`{#needsFormatting} file(s) were not formatted properly.`)
			end
		else
			print(`Formatted {#needsFormatting} of {#sourceFiles} file(s).`)
		end
	end

	if check and #needsFormatting > 0 then
		print(`\n{#needsFormatting} file(s) not formatted:\n\t- {table.concat(needsFormatting, "\n\t- ")}`)
	end

	if #failed > 0 then
		print(`\n{#failed} file(s) could not be formatted:\n\t- {table.concat(failed, "\n\t- ")}`)
	end

	if #failed > 0 or (check and #needsFormatting > 0) then
		process.exit(1)
	end
end

main(...)
