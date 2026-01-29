local cli = require("@batteries/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local tbl = require("@std/tableext")
local difftext = require("@batteries/difftext")

local FAILLIST_PATH = "tools/check-faillist.txt"

local TYPECHECK_PATHS = {
	"examples",
	"lute/cli",
	"lute/std/libs",
	"tests",
	"tools",
}

local function collectFiles(dir: string): { string }
	local files: { string } = {}
	local it = fs.walk(dir, { recursive = true })
	local p = it()
	while p do
		local pathStr = path.format(p)
		if fs.type(p) == "file" and string.match(pathStr, "%.luau$") then
			table.insert(files, pathStr)
		end
		p = it()
	end
	table.sort(files)
	return files
end

local function getAllFiles(): { string }
	local allFiles: { string } = {}
	for _, dir in TYPECHECK_PATHS do
		local files = collectFiles(dir)
		tbl.extend(allFiles, files)
	end
	return allFiles
end

local function readFaillist(): string
	local ok, file = pcall(fs.open, FAILLIST_PATH, "r")
	if not ok or not file then
		return ""
	end

	local contents = fs.read(file)
	fs.close(file)
	return contents
end

local function writeFaillist(contents: string): ()
	local file = fs.open(FAILLIST_PATH, "w+")
	fs.write(file, contents)
	fs.close(file)
end

local function runTypecheck(lutePath: string, files: { string }): string
	local args: { string } = { lutePath, "check" }
	for _, file in files do
		table.insert(args, file)
	end
	local result = process.run(args)
	return result.stdout .. result.stderr
end

type ErrorEntry = {
	file: string,
	line: number,
	col: number,
	colEnd: number,
}

-- We need this so that the faillist is machine agnostic
-- e.g. homedirs shouldnt show up in the path
local function relativePath(p: string, cwdStr: string): string
	local cwdWithSep = cwdStr
	if string.sub(cwdWithSep, -1) ~= "/" then
		cwdWithSep = cwdWithSep .. "/"
	end
	if string.sub(p, 1, #cwdWithSep) == cwdWithSep then
		p = string.sub(p, #cwdWithSep + 1)
	end

	if string.sub(p, 1, 2) == "./" then
		p = string.sub(p, 3)
	end

	return p
end

local function parseErrors(output: string, cwdStr: string): { ErrorEntry }
	local errors: { ErrorEntry } = {}

	for line in string.gmatch(output, "[^\n]+") do
		-- Matches the output of the `report` function in tc.cpp: path:line:col-colEnd: ...
		local file, lineNum, col, colEnd = string.match(line, "^(.+):(%d+):(%d+)-(%d+):")

		if file and lineNum then
			table.insert(errors, {
				file = relativePath(file, cwdStr),
				line = tonumber(lineNum) :: number,
				col = tonumber(col) :: number,
				colEnd = tonumber(colEnd) :: number,
			})
		end
	end

	return errors
end

local function sortErrors(errors: { ErrorEntry }): { ErrorEntry }
	table.sort(errors, function(a: ErrorEntry, b: ErrorEntry)
		if a.file ~= b.file then
			return a.file < b.file
		end
		if a.line ~= b.line then
			return a.line < b.line
		end
		if a.col ~= b.col then
			return a.col < b.col
		end
		return a.colEnd < b.colEnd
	end)
	return errors
end

local function formatFaillist(errors: { ErrorEntry }): string
	local lines: { string } = {}

	for _, err in errors do
		table.insert(lines, `{err.file}:{err.line}:{err.col}-{err.colEnd}`)
	end

	return table.concat(lines, "\n") .. "\n"
end

local function main(args: { string })
	local parser = cli.parser()
	parser:add("update", "flag", { help = "Update the faillist file", aliases = { "u" } })
	parser:add("check", "positional", { help = "This script" })
	parser:add("lute", "positional", { help = "Path to lute executable", required = true })
	parser:parse(args)

	local shouldUpdate = parser:has("update")
	local lutePath = parser:get("lute")
	assert(lutePath, "Missing required lute path argument")

	print("Collecting files to typecheck...")
	local allFiles = getAllFiles()
	print(`Found {#allFiles} files`)

	print("Running typecheck...")
	local output = runTypecheck(lutePath, allFiles)

	local cwdStr = path.format(process.cwd())
	local errors = parseErrors(output, cwdStr)
	local sortedErrors = sortErrors(errors)
	local formattedOutput = formatFaillist(sortedErrors)

	local oldFaillist = readFaillist()

	if shouldUpdate then
		writeFaillist(formattedOutput)
		print(`Updated {FAILLIST_PATH} with {#sortedErrors} errors`)
		return
	end

	if oldFaillist == formattedOutput then
		print("\nTypecheck passed! (output matches faillist)")
		return
	end

	print("\nTypecheck output differs from faillist:")
	print(difftext.prettydiff(oldFaillist, formattedOutput, { detailed = true, includeLineNumbers = true }))
	print("\nRun with --update to update the faillist, or fix the errors.")
	process.exit(1)
end

main({ ... })
