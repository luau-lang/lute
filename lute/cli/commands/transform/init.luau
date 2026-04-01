local fs = require("@std/fs")
local luau = require("@std/luau")
local pathLib = require("@std/path")
local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")

local arguments = require("@self/lib/arguments")
local files = require("./lib/files")
local types = require("@self/lib/types")

local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
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

		local source = fs.readfiletostring(pathStr)

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
				print(`Marking {pathStr} for deletion`)
				table.insert(deletedPaths, pathStr)
			end
		elseif not dryRun then
			if outputFilePath then
				assert(outputFilePath ~= nil)
				fs.writestringtofile(outputFilePath, toWrite)
			elseif toWrite ~= source then
				fs.writestringtofile(pathStr, toWrite)
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

local function main(...: string)
	local args = arguments.parse({ ... })

	if args.dryRun then
		print("Executing in dry run mode")
	end

	if args.outputFile then
		print(`Output path specified: '{args.outputFile}'`)
	end

	print(`Loading migration '{args.migrationPath}'`)
	local migration = loadMigration(args.migrationPath)

	print("Finding source files") -- todo: might type error
	local files = files.getSourceFiles(args.filePaths)
	if #files == 0 then
		error("error: no source files provided")
	end

	print("Processing migration options")
	local migrationOptions = processMigrationOptions(migration, args.migrationOptions)

	print("Applying migration")
	applyMigration(migration, files, migrationOptions, args.dryRun, args.outputFile)

	print(`Processed {#files} files!`)
end

main(...)
