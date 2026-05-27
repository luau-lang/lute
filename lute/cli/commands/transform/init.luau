local fs = require("@std/fs")
local luau = require("@std/luau")
local pathLib = require("@std/path")
local process = require("@std/process")
local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")

local richterm = require("@batteries/richterm")
local io = require("@std/io")
local printDiffHunks = require("./transform/printDiffHunks")
local cli = require("@batteries/cli")
local files = require("./lib/files")
local types = require("@self/types")

local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function confirmChange(prompt: string): boolean
	local userInput = io.input(prompt)
	local answer = userInput:match("^%s*(.-)%s*$") or ""
	return answer:lower() == "y"
end

local function loadMigration(path: string): types.Migration
	local success, loaded = pcall(luau.loadModule, path, nil)
	assert(success, `{path} failed to require: {loaded}`)
	assert(loaded, `{path} is missing a return`)

	if typeof(loaded) == "function" then
		local migration = {}
		migration.transform = loaded
		return migration :: types.Migration -- FIXME: Luau
	elseif typeof(loaded) == "table" then
		-- FIXME(Luau): https://github.com/luau-lang/luau/issues/1803 for the type assertions
		assert(
			typeof((loaded :: any).transform) == "function",
			`{path} must contain a 'transform' property of type function`
		)
		if (loaded :: any).options then
			assert(typeof(loaded.options) == "table", `Expected return of {path}.options to be a table`)
			for _, option in loaded.options do
				assert(typeof(option.name) == "string", `Expected option.name to be a string`)
				assert(
					option.kind == "string" or option.kind == "boolean",
					`Expected option.kind to be either 'string' or 'boolean', got {option.kind}`
				)
			end
		end
		if (loaded :: any).initialize then
			assert(typeof(loaded.initialize) == "function", `Expected {path}.initialize to be a function`)
		end
		return loaded :: types.Migration
	else
		error(`Expected '{path}' to return a function or table, got {typeof(loaded)}`)
	end
end

local function processMigrationOptions(migration: types.Migration, options: { [string]: string }): { [string]: any }
	if migration.options == nil then
		return table.freeze({}) :: any -- FIXME(Luau): https://github.com/luau-lang/luau/issues/1802
	end

	local processedOptions: { [string]: string | boolean } = {}

	for _, option in migration.options do
		local value = options[option.name]
		if value then
			if option.kind == "boolean" then
				local lowered = value:lower()
				assert(
					lowered == "true" or lowered == "false",
					`Option '--{option.name}' expects a boolean value 'true' or 'false'`
				)
				processedOptions[option.name] = lowered == "true"
			elseif option.kind == "string" then
				processedOptions[option.name] = value
			else
				exhaustiveMatch(option.kind)
			end
		else
			assert(option.default ~= nil, `Missing required option '--{option.name}'`)
			processedOptions[option.name] = option.default
		end
	end

	return table.freeze(processedOptions)
end

local function applyMigration(
	migration: types.Migration,
	paths: { pathLib.Path },
	options: { [string]: string | boolean },
	dryRun: boolean,
	interactive: boolean,
	outputPath: string?
)
	local deletedPaths = {}

	if migration.initialize then
		print("Initializing migration")
		local ctx = {
			options = options,
		}
		migration.initialize(ctx)
	end

	local outputFilePath = if outputPath then pathLib.parse(outputPath) else nil

	for _, pathObj in paths do
		local pathStr = pathLib.format(pathObj)

		print(`Applying to {pathStr}`)

		local source = fs.readFileToString(pathStr)

		local parseresult = syntax.parse(source)

		local ctx = {
			path = pathStr,
			source = source,
			parseresult = parseresult,
			options = options,
		}

		-- TODO: should we wrap in pcall? For now we don't do this to preserve stack trace
		local result = migration.transform(ctx)

		local toWrite = if typeof(result) == "string" then result else printer.printFile(parseresult, result)

		if toWrite == types.DELETION_MARKER then
			if outputFilePath then
				print(`Skipping writing {pathStr} as it was marked for deletion`)
			else
				local deletionConfirmed = true
				if interactive then
					-- prompt to confirm deletion
					deletionConfirmed = confirmChange(richterm.bold(`\nDelete {pathStr}? (y/n)`))
				end

				if deletionConfirmed then
					print(`Marking {pathStr} for deletion`)
					table.insert(deletedPaths, pathStr)
				end
			end
		elseif not dryRun then
			if outputFilePath then
				assert(outputFilePath ~= nil)
				fs.writeStringToFile(outputFilePath, toWrite)
			elseif toWrite ~= source then
				local changesConfirmed = true
				if interactive then
					local fileDiff = printDiffHunks(source, toWrite)

					-- First: print out diff w/ option to accept / deny
					print(`\n` .. fileDiff .. `\n`)
					changesConfirmed = confirmChange(richterm.bold(`Accept changes to {pathStr}? (y/n)`))
					print(if changesConfirmed then `Changes confirmed` else `Changes denied` .. `\n`)
				end
				if changesConfirmed then
					fs.writeStringToFile(pathStr, toWrite)
				end
			end
		end
	end

	if not dryRun then
		for _, pathStr in deletedPaths do
			print(`Deleting {pathStr}`)
			fs.remove(pathStr)
		end
	end
end

local USAGE = "Usage: lute transform [options] <migration-path> [files...] [-- [--option value...]]"

local function printHelp()
	print(USAGE)
	print([[
Apply the specified code transformation to the given files.

OPTIONS:
  -h, --help              Show this help message
  --dry-run               Preview changes without writing files
  -o, --output [FILE]     Write output to a single file instead of in-place (only works if a single input file is specified)

lute transform also supports forwarding options to the code transformation script by placing them after a '--' separator. For example:

  lute transform my-migration.luau files/ -- --option value
	]])
end

local function main(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("dry-run", "flag", { help = "Preview changes without writing any files" })
	args:add(
		"interactive",
		"flag",
		{ help = "Interactive mode, where you can preview and confirm changes", aliases = { "i" } }
	)
	args:add("output", "option", { help = "Write output to this file (single input only)", aliases = { "o" } })
	args:add("migration-path", "positional", { help = "Path to the migration script to run" })
	args:add(
		"files",
		"variadic",
		{ help = "Files or directories to apply the migration to (defaults to current directory if not specified)" }
	)
	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	local migrationPath = args:get("migration-path")
	if not migrationPath then
		print(`Error: No code transformation script specified.\n\n{USAGE}\nUse --help for more information.`)
		process.exit(1)
		error("Unreachable") -- LUAUFIX: Remove once we can refine migrationPath is string outside this block
	end

	local dryRun = args:has("dry-run")
	local interactive = args:has("interactive")
	local outputFile = args:get("output")

	-- Split forwarded args into file paths and migration options.
	-- Non-flag tokens are file paths; --name value pairs are migration options.
	local filePaths: { string } = args:variadics()
	local migrationOptions: { [string]: string } = {}
	local forwarded = args:forwarded() or {}
	local i = 1
	while i <= #forwarded do
		local token = forwarded[i]
		local name = string.sub(token, 3)
		i += 1
		assert(i <= #forwarded, `Missing value for '--{name}'`)
		migrationOptions[name] = forwarded[i]
		i += 1
	end

	assert(outputFile == nil or #filePaths == 1, "When specifying an output file, only one input file is allowed")

	if dryRun then
		print("Executing in dry run mode")
	end

	if interactive then
		print("Executing in interactive mode")
	end

	if outputFile then
		print(`Output path specified: '{outputFile}'`)
	end

	print(`Loading migration '{migrationPath}'`)
	local migration = loadMigration(migrationPath)

	print("Finding source files")
	local sourceFiles = files.getSourceFiles(filePaths)
	if #sourceFiles == 0 then
		error("error: no source files provided")
	end

	print("Processing migration options")
	local processedOptions = processMigrationOptions(migration, migrationOptions)

	print("Applying migration")
	applyMigration(migration, sourceFiles, processedOptions, dryRun, interactive, outputFile)

	print(`Processed {#sourceFiles} files!`)
end

main(...)
