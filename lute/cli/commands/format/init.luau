local cli = require("@batteries/cli")
local files = require("./lib/files")
local fs = require("@std/fs")
local formatter = require("@std/syntax/format")
local io = require("@std/io")
local pathLib = require("@std/path")
local process = require("@std/process")
local printDiffHunks = require("./transform/printDiffHunks")

local STDIN_SENTINEL = "__lute_format_stdin__"
local USAGE = "Usage: lute format [options] [paths...]"

local function printHelp()
	print(USAGE)
	print([[
Format Luau source files with Lute's built-in formatter.

OPTIONS:
  -h, --help     Show this help message
  --check        Report files that would change without writing them

PATHS:
  File(s) or directories to format. Directories are searched recursively for .luau and .lua files.
  If no paths are provided, lute format formats the current directory.
  Use '-' as the only path to read from stdin and write formatted source to stdout.

The formatter intentionally does not read project, editor, or user configuration.
]])
end

local function readStdin(): string
	local lines = {}

	while true do
		local ok, line = pcall(function()
			return io.input()
		end)
		if not ok then
			break
		end
		table.insert(lines, line)
	end

	return table.concat(lines, "\n")
end

local function formatSource(source: string, label: string): (boolean, string)
	local ok, result = pcall(formatter.formatCode, source)
	if ok then
		return true, result
	end

	return false, `Error formatting {label}: {result}`
end

local function formatStdin(): ()
	local ok, result = formatSource(readStdin(), "stdin")
	if not ok then
		print(result)
		process.exit(1)
	end

	io.write(result)
end

local function formatPath(pathObj: pathLib.Path, check: boolean): boolean
	local pathStr = pathLib.format(pathObj)
	local source = fs.readFileToString(pathStr)
	local ok, result = formatSource(source, pathStr)

	if not ok then
		print(result)
		return false
	end

	if result == source then
		return true
	end

	if check then
		print(`Would reformat {pathStr}`)
		local diff = printDiffHunks(source, result)
		if diff ~= "" then
			print(diff)
		end
		return false
	end

	fs.writeStringToFile(pathStr, result)
	print(`Formatted {pathStr}`)
	return true
end

local function main(...: string)
	local rawArgs = { ... }
	local stdinRequested = false
	for index, value in rawArgs do
		if value == "-" then
			stdinRequested = true
			rawArgs[index] = STDIN_SENTINEL
		end
	end

	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("check", "flag", { help = "Report files that would change without writing them" })
	args:add("paths", "variadic", { help = "Files or directories to format" })
	args:parse(rawArgs)

	if args:has("help") then
		printHelp()
		return
	end

	local paths = args:variadics()
	if stdinRequested then
		if #paths ~= 1 or paths[1] ~= STDIN_SENTINEL then
			print("Error: '-' cannot be combined with file or directory paths.")
			process.exit(1)
		end
		formatStdin()
		return
	end

	if #paths == 0 then
		paths = { "." }
	end

	local sourceFiles = files.getSourceFiles(paths)
	if #sourceFiles == 0 then
		print("Error: No Luau source files found.")
		process.exit(1)
	end

	local check = args:has("check")
	local allOk = true
	for _, sourcePath in sourceFiles do
		if not formatPath(sourcePath, check) then
			allOk = false
		end
	end

	process.exit(if allOk then 0 else 1)
end

main(...)
