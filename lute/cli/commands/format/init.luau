const cli = require("@batteries/cli")
const format = require("@self/format")
const fs = require("@std/fs")
const path = require("@std/path")
const process = require("@std/process")

const configs = require("./lib/configs")
const files = require("./lib/files")
const parseIgnores = require("./lib/parseIgnores")

const DESCRIPTION = [[

Format Luau source files. Experimental: formatting is still under development, and its output will change.
]]

const function findConfiguredIgnores(): parseIgnores.GitignoreData?
	for configPath, config in configs.walkConfigPaths() do
		const luteConfig = config.lute
		if typeof(luteConfig) ~= "table" then
			continue
		end

		const formatConfig = luteConfig.format
		if typeof(formatConfig) ~= "table" or formatConfig.ignores == nil then
			continue
		end

		const ignores = formatConfig.ignores
		if typeof(ignores) ~= "table" then
			error(`{configPath}: lute.format.ignores must be an array of filepath globs`, 0)
		end

		return parseIgnores.parseIgnoreContents(path.dirname(configPath), ignores)
	end

	return nil
end

const function filterIgnored(sourceFiles: { path.Path }, verbose: boolean): { path.Path }
	const ignoreData = findConfiguredIgnores()
	if ignoreData == nil then
		return sourceFiles
	end

	const kept: { path.Path } = {}
	for _, sourcePath in sourceFiles do
		const target = path.format(sourcePath)

		if parseIgnores.isIgnored(ignoreData, target, false) then
			if verbose then
				print(`Skipping {target}`)
			end
			continue
		end

		table.insert(kept, sourcePath)
	end

	if verbose then
		print(`Kept {#kept} file(s) after filtering.`)
	end

	return table.freeze(kept)
end

const function main(...: string)
	const args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("verbose", "flag", { help = "Enable verbose output", aliases = { "v" } })
	args:add("check", "flag", { help = "Check formatting; exit 1 if any file is unformatted", aliases = { "c" } })
	args:add("no-ignore", "flag", { help = "Format every input, even ones matching lute.format.ignores" })
	args:add("files", "variadic", { help = "Files or directories to format (defaults to current directory)" })
	args:parse({ ... })

	if args:has("help") then
		print(args:usage("lute format"))
		print(DESCRIPTION)
		print(args:help())
		return
	end

	const check = args:has("check")
	const verbose = args:has("verbose")

	local inputPaths = args:variadics()
	if #inputPaths == 0 then
		inputPaths = table.freeze({ "." })
	end

	const failed: { string } = {}
	const needsFormatting: { string } = {}

	local sourceFiles = files.getSourceFiles(inputPaths, verbose)
	if not args:has("no-ignore") then
		sourceFiles = filterIgnored(sourceFiles, verbose)
	end
	if verbose then
		print(`Found {#sourceFiles} file(s) to format.`)
	end

	for _, sourcePath in sourceFiles do
		const target = path.format(sourcePath)

		if verbose then
			print(`Trying to format {target}`)
		end

		const read, source = pcall(fs.readFileToString, sourcePath)
		if not read then
			if verbose then
				print(`Failed to read {target}`)
			end
			table.insert(failed, `{target}: {source}`)
			continue
		end

		const ok, formatted = pcall(format.formatSource, source)
		if not ok then
			if verbose then
				print(`Failed to format {target}`)
			end
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
