local cli = require("@batteries/cli")
local files = require("./lib/files")
local formatter = require("@std/syntax/format")
local io = require("@std/io")
local pathLib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local task = require("@std/task")
local vm = require("@lute/vm")

local STDIN_SENTINEL = "__lute_format_stdin__"
local USAGE = "Usage: lute format [options] [paths...]"
local CHUNKS_PER_WORKER = 4

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

type FormatResult = {
	ok: boolean,
	changed: boolean,
	output: string,
}

local function formatPaths(sourceFiles: { pathLib.Path }, check: boolean): boolean
	local nfiles = #sourceFiles
	local nworkers = math.max(1, math.min(system.threadCount(), nfiles))
	local chunkSize = math.max(1, math.ceil(nfiles / (nworkers * CHUNKS_PER_WORKER)))
	local pathStrings = table.create(nfiles) :: { string }
	local results = table.create(nfiles) :: { FormatResult? }
	local workerFailures: { string } = {}
	local cursor = 1

	for index, sourcePath in sourceFiles do
		pathStrings[index] = pathLib.format(sourcePath)
	end

	local function takenext(): (number?, { string }?)
		if cursor > nfiles then
			return nil, nil
		end

		local startIndex = cursor
		local endIndex = math.min(nfiles, startIndex + chunkSize - 1)
		local chunk = table.create(endIndex - startIndex + 1) :: { string }
		for index = startIndex, endIndex do
			table.insert(chunk, pathStrings[index])
		end
		cursor = endIndex + 1
		return startIndex, chunk
	end

	local done = 0
	for _ = 1, nworkers do
		task.spawn(function()
			local currentPath: string? = nil
			xpcall(function()
				local worker = vm.create("@self/worker") :: any
				while true do
					local startIndex, chunk = takenext()
					if startIndex == nil or chunk == nil then
						break
					end

					currentPath = chunk[1]
					local chunkResults = worker.formatfiles({
						files = chunk,
						check = check,
					}) :: { FormatResult }
					for offset, result in chunkResults do
						results[startIndex + offset - 1] = result
					end
				end
			end, function(err: any)
				local where = currentPath or "<worker setup>"
				table.insert(workerFailures, `worker errored while formatting {where}: {tostring(err)}`)
			end)
			done += 1
		end)
	end

	while done < nworkers do
		task.wait()
	end

	local allOk = #workerFailures == 0
	for index = 1, nfiles do
		local result = results[index]
		if result == nil then
			local pathStr = pathStrings[index]
			print(`Error formatting {pathStr}: worker did not return a result`)
			allOk = false
		else
			if result.output ~= "" then
				io.write(result.output)
			end
			if not result.ok or (check and result.changed) then
				allOk = false
			end
		end
	end

	for _, failure in workerFailures do
		print(failure)
	end

	return allOk
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
	process.exit(if formatPaths(sourceFiles, check) then 0 else 1)
end

main(...)
