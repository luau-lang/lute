--!strict

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local cli = require("@batteries/cli")
local difftext = require("@batteries/difftext")

local FAILLIST_PATH = "tools/check-faillist.txt"

-- Directories to typecheck
local TYPECHECK_PATHS = {
	"tests",
	"lute/std/libs",
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
		for _, file in files do
			table.insert(allFiles, file)
		end
	end
	table.sort(allFiles)
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
	-- Run lute check on all files
	local args: { string } = { lutePath, "check" }
	for _, file in files do
		table.insert(args, file)
	end

	print("> " .. table.concat(args, " "))
	local result = process.run(args)
	return result.stdout .. result.stderr
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

	local oldFaillist = readFaillist()

	if shouldUpdate then
		writeFaillist(output)
		print(`Updated {FAILLIST_PATH}`)
		return
	end

	-- Compare against faillist
	if oldFaillist == output then
		print("\nTypecheck passed! (output matches faillist)")
		return
	end

	print("\nTypecheck output differs from faillist:")
	print(difftext.prettydiff(oldFaillist, output, { detailed = true, includeLineNumbers = true }))
	print("\nRun with --update to update the faillist, or fix the errors.")
	process.exit(1)
end

main({ ... })
