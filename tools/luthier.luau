--!strict

-- Luthier intentionally uses the runtime `@lute` APIs, instead of the standard library in order to support bootstrapping from scratch.
-- Since Luthier is responsible for generating the files that embed `@std` into Lute, it cannot depend on `@std` being available.
-- Avoid using `@std` here to prevent bootstrap issues.

local crypto = require("@lute/crypto")
local fs = require("@lute/fs")
local process = require("@lute/process")
local system = require("@lute/system")
local cli = require("@batteries/cli")
local richterm = require("@batteries/richterm")
local toml = require("@batteries/toml")

type Tune = {
	dependency: {
		name: string,
		remote: string,
		branch: string,
		revision: string,
	},
}

local BUILD_DIR = "build"

local cwd = process.cwd()

local function gitVersion(): { major: number, minor: number, path: number }
	local gitVersionString = process.run({ "git", "--version" }).stdout
	local gitVersion = string.split(gitVersionString, " ")[3]
	local components = string.split(gitVersion, ".")
	return {
		major = tonumber(components[1]) or 0,
		minor = tonumber(components[2]) or 0,
		path = tonumber(components[3]) or 0,
	}
end

local function readFileToString(path: string): string
	local file = fs.open(path, "r")
	local contents = fs.read(file)
	fs.close(file)
	return contents
end

local function writeStringToFile(path: string, contents: string): ()
	local file = fs.open(path, "w+")
	fs.write(file, contents)
	fs.close(file)
end

local gitVersionInfo = gitVersion()

local os = string.lower(system.os)
local isWindows = string.find(os, "windows") ~= nil
local isMac = string.find(os, "darwin") ~= nil
local isLinux = string.find(os, "linux") ~= nil

local targetMap: { [string]: { exeName: string } } = {
	lute = {
		exeName = "lute/cli/lute",
	},
	["Lute.CLI"] = {
		exeName = "lute/cli/lute",
	},
	["Lute.Test"] = {
		exeName = "tests/lute-tests",
	},
}

local args = cli.parser()

args:add("help", "flag", { help = "show the help message" })
args:add("luthier", "positional", { help = "the luthier script", required = true, hidden = true }) -- should this be handled automatically?
args:add("subcommand", "positional", { help = "command to execute", required = true, hidden = true })
args:add("target", "positional", { help = "the thing to build or run" })
args:add("verbose", "flag", { help = "show verbose compile output", aliases = { "v" } })
args:add("config", "option", { help = "configuration (default is debug)", default = "debug" })
args:add("clean", "flag", { help = "perform a clean build" })
args:add("which", "flag", { help = "print out the path to the compiled binary and exit", aliases = { "w" } })
args:add("cxx-compiler", "option", { help = "C++ compiler to use" })
args:add("c-compiler", "option", { help = "C compiler to use" })
args:add("enable-sanitizers", "flag", { help = "enable sanitizers during configuration" })

if not isWindows and not isMac and not isLinux then
	error("Unknown platform " .. os)
end

local pathSep = if isWindows then "\\" else "/"

local function joinPath(...)
	return table.concat({ ... }, pathSep)
end

local function projectRelative(...)
	return joinPath(cwd, ...)
end

local function findLast(haystack: string, needle: string): number?
	local lastPos
	local currentPos = 1
	while true do
		local foundPos = string.find(haystack, needle, currentPos, true)
		if foundPos then
			lastPos = foundPos
			currentPos = foundPos + 1
		else
			break -- No more occurrences
		end
	end
	return lastPos
end

local function safeFsType(path: string): string?
	local success, res = pcall(fs.type, path)
	if success then
		return res
	else
		return nil
	end
end

local function getSourceRoot()
	local cwd = process.cwd()

	while true do
		if safeFsType(cwd .. pathSep .. ".LUTE_SENTINEL") == "file" then
			return cwd
		end

		local lastSep = findLast(cwd, pathSep)
		if lastSep then
			cwd = string.sub(cwd, 1, lastSep - 1)
		else
			break
		end
	end

	if process.env.LUTE_ROOT_DIR then
		return process.env.LUTE_ROOT_DIR
	end

	error(
		"Could not locate lute project root.  Your cwd must be in your lute checkout, or the LUTE_ROOT_DIR environment variable must be set."
	)
end

local function getExeName(target: string): string
	local baseName = targetMap[target].exeName
	local ext = if isWindows then ".exe" else ""
	return baseName .. ext
end

local function getCompiler(): string
	if isMac then
		return "xcode"
	else
		return "vs2022"
	end
end

local function getConfig(): string
	return assert(args:get("config"))
end

local function getBuildDir(): string
	local config = string.lower(getConfig())

	if isLinux then
		return joinPath(BUILD_DIR, config)
	else
		return joinPath(BUILD_DIR, getCompiler(), config)
	end
end

local function getProjectPath(): string
	return projectRelative(getBuildDir())
end

local function projectPathExists(): boolean
	local projectPath = getProjectPath()

	return safeFsType(projectPath) == "dir"
end

local function buildManifestExists(): boolean
	return safeFsType(joinPath(getProjectPath(), "build.ninja")) == "file"
end

local function hexify(digest)
	local hex = {}
	for i = 1, buffer.len(digest) do
		hex[i] = string.format("%02x", buffer.readu8(digest, i - 1))
	end
	return table.concat(hex)
end

local function traverseFileTree(path: string, callback: (string, string) -> ())
	local directories: { { path: string, relativePath: string } } = { { path = path, relativePath = "" } }

	while #directories > 0 do
		local currentDir = directories[1]
		callback(currentDir.path, currentDir.relativePath)

		local contents = fs.listdir(currentDir.path)
		-- FIXME(Luau): bidirectional typing
		table.sort(contents, function(a: fs.DirectoryEntry, b: fs.DirectoryEntry)
			return a.name < b.name
		end)

		for _, file in contents do
			local fullPath = currentDir.path .. "/" .. file.name

			if safeFsType(fullPath) ~= "file" then
				continue
			end

			local fullRelativePath = currentDir.relativePath
			if #fullRelativePath ~= 0 then
				fullRelativePath ..= "/"
			end
			fullRelativePath ..= file.name

			callback(fullPath, fullRelativePath)
		end

		for _, directory in contents do
			local fullPath = currentDir.path .. "/" .. directory.name

			if safeFsType(fullPath) ~= "dir" then
				continue
			end

			local fullRelativePath = currentDir.relativePath
			if #fullRelativePath ~= 0 then
				fullRelativePath ..= "/"
			end
			fullRelativePath ..= directory.name

			table.insert(directories, { path = fullPath, relativePath = fullRelativePath })
		end

		table.remove(directories, 1)
	end
end

local function writeLines(file, lines: { string })
	fs.write(file, table.concat(lines, "\n") .. "\n")
end

local function hashDirectory(path: string): string
	local toHash = ""
	traverseFileTree(path, function(filePath, relativePath)
		if safeFsType(filePath) == "file" then
			toHash ..= "./" .. relativePath
			toHash ..= readFileToString(filePath)
		end
	end)
	local digest = crypto.digest(crypto.hash.blake2b256, toHash)
	return hexify(digest)
end

local function isHashUpToDate(hashFile: string, currentHash: string): boolean
	if safeFsType(hashFile) ~= "file" then
		return false
	end
	return readFileToString(hashFile) == currentHash
end

type EmbeddedModuleConfig = {
	sourcePath: string,
	outputDir: string,
	alias: string,
	arrayName: string,
	moduleName: string,
}

local function generateEmbeddedModulesIfNeeded(config: EmbeddedModuleConfig)
	pcall(fs.mkdir, config.outputDir)

	local hashFile = joinPath(config.outputDir, "hash.txt")
	local currentHash = hashDirectory(config.sourcePath)

	if isHashUpToDate(hashFile, currentHash) then
		return
	end
	local aliasWithSlash = config.alias .. "/"
	local logMsg = `Generating code for embedded {aliasWithSlash} modules, files are out of date`
	print(logMsg)
	local cppFile = config.moduleName .. ".cpp"
	local headerFile = config.moduleName .. ".h"

	local delimiter = string.upper(config.moduleName) .. "_MOD"
	if #delimiter >= 16 then
		print(`Delimiter {delimiter} cannot be greater than length 16. Please shorten the embedded module name`)
		process.exit(1)
	end

	local cpp = fs.open(joinPath(config.outputDir, cppFile), "w+")

	writeLines(cpp, {
		"// This file is auto-generated by luthier.luau. Do not edit.",
		`// Instead, you should modify the source files in \`{config.sourcePath}\`.`,
		"",
		`#include "{headerFile}"`,
		"",
		`const std::pair<std::string_view, std::string_view> {config.arrayName}[] = \{`,
	})

	local numItems = 0

	traverseFileTree(config.sourcePath, function(path, relativePath)
		if #relativePath == 0 then
			return -- Skip the root directory
		end

		local aliasedPath = aliasWithSlash .. relativePath

		if safeFsType(path) == "file" then
			local libSrc = readFileToString(path)
			if #libSrc > 16_000 then
				-- https://learn.microsoft.com/en-us/cpp/error-messages/compiler-errors-1/compiler-error-c2026
				-- MSVC can't handle a single string literal being over 16380 single-byte characters,
				-- but can if they are adjacent concatenated strings. So, we split the string line-by-line into
				-- adjacent substrings.
				local lines = string.split(libSrc, "\n")
				local generatedLines = table.create(#lines)
				for _, line in lines do
					local escapedLine = string.gsub(line, "\\", "\\\\")
					escapedLine = string.gsub(escapedLine, '"', '\\"')
					escapedLine = string.gsub(escapedLine, "\r", "")
					table.insert(generatedLines, `"{escapedLine}\\n"`)
				end
				fs.write(cpp, `\n    \{"{aliasedPath}", {table.concat(generatedLines, "\n")}},\n`)
			else
				fs.write(cpp, `\n    \{"{aliasedPath}", R"{delimiter}({libSrc}){delimiter}"},\n`)
			end
		end

		if safeFsType(path) == "dir" then
			fs.write(cpp, `\n    \{"{aliasedPath}", "#directory"},\n`)
		end

		numItems += 1
	end)

	fs.write(cpp, "};\n")
	fs.close(cpp)

	local header = fs.open(joinPath(config.outputDir, headerFile), "w+")
	writeLines(header, {
		"// This file is auto-generated by luthier.luau. Do not edit.",
		"#pragma once",
		"",
		"#include <string_view>",
		"#include <utility>",
		"",
		`extern const std::pair<std::string_view, std::string_view> {config.arrayName}[{numItems}];`,
	})
	fs.close(header)

	writeStringToFile(hashFile, currentHash)
end

local function getTypeDefinitionsHash(): string
	local libsPath = projectRelative("definitions")
	local stdPath = projectRelative("lute", "std", "libs")

	local toHash = ""

	local function traverseDefs(path: string, namespace: string)
		traverseFileTree(path, function(path, relativePath)
			if safeFsType(path) == "file" then
				toHash ..= `./{namespace}/{relativePath}`
				toHash ..= readFileToString(path)
			end
		end)
	end

	traverseDefs(libsPath, "lute")
	traverseDefs(stdPath, "std")

	local digest = crypto.digest(crypto.hash.blake2b256, toHash)
	return hexify(digest)
end

local function generateTypeDefinitionFiles()
	local generatedPath = projectRelative("lute", "cli", "commands", "setup", "generated")
	pcall(fs.mkdir, generatedPath)

	local hashFile = joinPath(generatedPath, "hash.txt")
	local currentHash = getTypeDefinitionsHash()

	if isHashUpToDate(hashFile, currentHash) then
		return
	end

	print("Type definitions out of date, creating new ones.")

	local libsPath = projectRelative("definitions")
	local stdPath = projectRelative("lute", "std", "libs")
	local dictionaryEntries: { [string]: string } = {}

	local function traverseDefs(path: string, namespace: string)
		traverseFileTree(path, function(path, relativePath)
			if safeFsType(path) == "file" then
				local content = readFileToString(path)
				dictionaryEntries[`{namespace}/{relativePath}`] = content
			end
		end)
	end

	traverseDefs(libsPath, "lute")
	traverseDefs(stdPath, "std")

	dictionaryEntries["lint/types.luau"] =
		readFileToString(projectRelative("lute", "cli", "commands", "lint", "types.luau"))

	local stringDictionary = ""
	for key, value in dictionaryEntries do
		stringDictionary ..= string.format('["%*"] = [==[%*]==],', key, value)
	end

	writeStringToFile(hashFile, currentHash)

	writeStringToFile(
		projectRelative("lute", "cli", "commands", "setup", "generated", "definitions.luau"),
		string.format("return {%*}", stringDictionary)
	)
end

local function generateFilesIfNeeded()
	generateEmbeddedModulesIfNeeded({
		sourcePath = projectRelative("lute", "std", "libs"),
		outputDir = projectRelative("lute", "std", "src", "generated"),
		alias = "@std",
		arrayName = "lutestdlib",
		moduleName = "modules",
	})
	generateTypeDefinitionFiles()
	generateEmbeddedModulesIfNeeded({
		sourcePath = projectRelative("lute", "cli", "commands"),
		outputDir = projectRelative("lute", "cli", "generated"),
		alias = "@cli",
		arrayName = "luteclicommands",
		moduleName = "commands",
	})
	generateEmbeddedModulesIfNeeded({
		sourcePath = projectRelative("batteries"),
		outputDir = projectRelative("lute", "batteries", "generated"),
		alias = "@batteries",
		arrayName = "lutebatteries",
		moduleName = "batteries",
	})
	generateEmbeddedModulesIfNeeded({
		sourcePath = projectRelative("definitions"),
		outputDir = projectRelative("lute", "definitions", "src", "generated"),
		alias = "@lute",
		arrayName = "lutedefinitions",
		moduleName = "modules",
	})
end

local function getExePath(): string
	local target = args:get("target")
	assert(target ~= nil)
	local exeName = getExeName(target)

	return joinPath(getProjectPath(), exeName)
end

local function exeExists(): boolean
	local exePath = getExePath()

	return safeFsType(exePath) == "file"
end

local function call(cmd: { string }, passedCwd: string?): number
	print("> " .. table.concat(cmd, " "))

	return process.run(cmd, { cwd = passedCwd or cwd, stdio = "inherit" }).exitcode
end

local function removePathRecursive(path: string)
	local pathType = safeFsType(path)
	if pathType == nil then
		return
	end

	if pathType ~= "dir" then
		fs.remove(path)
		return
	end

	for _, entry in fs.listdir(path) do
		removePathRecursive(joinPath(path, entry.name))
	end

	fs.rmdir(path)
end

local function build()
	local target = args:get("target")
	assert(target ~= nil)
	local exeName = getExeName(target)
	local projectPath = getProjectPath()

	if args:has("clean") then
		call({ "ninja", "-C", projectPath, "clean" })
	end

	local cmd = { "ninja", "-C", projectPath, exeName }

	return call(cmd)
end

local function getConfigureArguments()
	local projectPath = getProjectPath()

	local config = string.lower(getConfig())
	if config == "debug" then
		config = "Debug"
	elseif config == "release" then
		config = "Release"
	end

	if args:has("clean") then
		print("> remove-tree " .. projectPath)
		removePathRecursive(projectPath)
	end

	local configArgs =
		{ "-G=Ninja", "-B " .. projectPath, "-DCMAKE_BUILD_TYPE=" .. config, "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }

	local cxx_compiler = args:get("cxx-compiler")
	if cxx_compiler then
		table.insert(configArgs, "-DCMAKE_CXX_COMPILER=" .. cxx_compiler)
	end

	local c_compiler = args:get("c-compiler")
	if c_compiler then
		table.insert(configArgs, "-DCMAKE_C_COMPILER=" .. c_compiler)
	end

	if args:has("enable-sanitizers") then
		table.insert(configArgs, "-DLUTE_ENABLE_SANITIZERS=ON")
	end

	return configArgs
end

local function readTuneFile(path: string): Tune
	-- We're promising that the thing we read _actually_ looks like a `Tune`,
	-- this could be ill advised.
	return toml.deserialize(readFileToString(path)) :: Tune
end

local function check(exitCode: number)
	if exitCode ~= 0 then
		error("Command failed with exit code " .. exitCode)
	end
end

local function printHelp()
	print("luthier — a build tool for lute")
	args:help(function(str)
		return richterm.combine(richterm.bold, richterm.yellow)(str)
	end)
end

local function usageError(message: string, details: string?, usage: string?)
	local lowercased = string.lower(string.sub(message, 1, 1)) .. string.sub(message, 2)
	print(richterm.combine(richterm.bold, richterm.red)(`Error: {lowercased}`))
	print(richterm.combine(richterm.bold, richterm.yellow)(`Usage: {usage or args:usage("luthier <subcommand>")}`))
	if details then
		print(richterm.combine(richterm.bold, richterm.yellow)(details))
	end
	print()
	printHelp()
	process.exit(1)
end

local function subcommandUsage(subcommand: string): string
	return args:usage(`luthier {subcommand}`)
end

local subcommands: { { string } } = {
	{ "fetch" },
	{ "generate" },
	{ "configure", "tune" },
	{ "build", "craft" },
	{ "run", "play" },
}

local function availableSubcommands(): string
	local parts = {}
	for _, group in subcommands do
		if #group > 1 then
			table.insert(parts, `{group[1]} (or {group[2]})`)
		else
			table.insert(parts, group[1])
		end
	end
	return `Available subcommands: {table.concat(parts, ", ")}`
end

local function availableTargets(): string
	local targets = {}
	for name in targetMap do
		table.insert(targets, name)
	end
	table.sort(targets)
	return `available targets: {table.concat(targets, ", ")}`
end

local function fetchDependency(dependencyInfo: Tune)
	local dependency = dependencyInfo.dependency

	if not dependency then
		error("tune file does not have a dependency table")
	end
	if not dependency.remote or not dependency.branch then
		error("Invalid dependency info in tune file: must have `remote` and `branch` fields")
	end

	local dependencyPath = projectRelative("extern", dependency.name)

	if safeFsType(dependencyPath) == "dir" then
		check(call({ "git", "fetch", "--depth=1", "origin", dependency.revision }, dependencyPath))
		return call({ "git", "checkout", dependency.revision }, dependencyPath)
	end

	if gitVersionInfo.major >= 3 or (gitVersionInfo.major == 2 and gitVersionInfo.minor >= 49) then
		return call({
			"git",
			"clone",
			"--depth=1",
			"--revision",
			dependency.revision,
			dependency.remote,
			"extern/" .. dependency.name,
		})
	else
		return call({
			"git",
			"clone",
			"--depth=1",
			"--branch",
			dependency.branch,
			dependency.remote,
			"extern/" .. dependency.name,
		})
	end
end

local function getTuneFilesHash(): string
	local externPath = projectRelative("extern")
	local files = fs.listdir(externPath)

	-- FIXME(Luau): bidirectional typing.
	table.sort(files, function(a: fs.DirectoryEntry, b: fs.DirectoryEntry)
		return a.name < b.name
	end)

	local toHash = ""

	for _, file in files do
		if not string.find(file.name, ".tune") then
			continue
		end

		if file.type ~= "file" then
			continue
		end

		toHash ..= file.name
		toHash ..= readFileToString(joinPath(externPath, file.name))
	end

	local digest = crypto.digest(crypto.hash.blake2b256, toHash)
	return hexify(digest)
end

local function areTuneFilesUpToDate(): boolean
	local hashFile = projectRelative("extern", "generated", "hash.txt")

	if safeFsType(hashFile) ~= "file" then
		return false
	end

	local hash = readFileToString(hashFile)
	return hash == getTuneFilesHash()
end

local function fetchDependencies(): number
	local files = fs.listdir(projectRelative("extern"))

	for _, file in files do
		if string.find(file.name, "%.tune$") then
			local dependencyInfo = readTuneFile(projectRelative("extern", file.name))
			check(fetchDependency(dependencyInfo))
		end
	end

	local generatedPath = projectRelative("extern", "generated")
	pcall(fs.mkdir, generatedPath)

	local hash = fs.open(joinPath(generatedPath, "hash.txt"), "w+")
	fs.write(hash, getTuneFilesHash())
	fs.close(hash)

	return 0
end

local function fetchDependenciesIfNeeded(): number
	if areTuneFilesUpToDate() then
		return 0
	end

	print("Fetching dependencies, tune files are out of date.")
	return fetchDependencies()
end

local function configure()
	local cmd = { "cmake" }
	local arguments = getConfigureArguments()

	table.move(arguments, 1, #arguments, 2, cmd)

	check(fetchDependenciesIfNeeded())

	local result = call(cmd)
	fs.copy(joinPath(getProjectPath(), "compile_commands.json"), projectRelative(BUILD_DIR, "compile_commands.json"))
	return result
end

local function run()
	local cmd = { getExePath() }
	local forwarded = args:forwarded() or {}

	table.move(forwarded, 1, #forwarded, 2, cmd)

	return call(cmd)
end

local parameters = { ... }
xpcall(function()
	args:parse(parameters)
end, function(e)
	-- Strip the "file:line: " prefix that Lua prepends to error messages
	local message = string.gsub(tostring(e), "^.+:%d+: ", "")
	usageError(message, availableSubcommands())
end)

cwd = getSourceRoot()

if args:has("help") then
	printHelp()
	return
end

if args:has("which") then
	print(getExePath())
	return
end

local subcommand = args:get("subcommand")

local exitCode = 0

if subcommand == "fetch" then
	exitCode = fetchDependencies()
elseif subcommand == "generate" then -- TODO cutesy name for generate
	generateFilesIfNeeded()
elseif subcommand == "configure" or subcommand == "tune" then
	generateFilesIfNeeded()
	exitCode = configure()
elseif subcommand == "build" or subcommand == "craft" then
	if not args:get("target") then
		usageError(`{subcommand} requires a target`, availableTargets(), subcommandUsage(subcommand))
	end

	generateFilesIfNeeded()

	if not projectPathExists() or not buildManifestExists() or not areTuneFilesUpToDate() then
		check(configure())
	end

	exitCode = build()
elseif subcommand == "run" or subcommand == "play" then
	if not args:get("target") then
		usageError(`{subcommand} requires a target`, availableTargets(), subcommandUsage(subcommand))
	end

	generateFilesIfNeeded()

	if not projectPathExists() or not buildManifestExists() or not areTuneFilesUpToDate() then
		check(configure())
	end

	if not exeExists() then
		check(build())
	end

	exitCode = run()
elseif subcommand ~= nil then
	usageError(`Unknown subcommand '{subcommand}'`, availableSubcommands())
else
	usageError("No subcommand given.", availableSubcommands())
end

if exitCode ~= 0 then
	error("Command failed with exit code " .. exitCode)
end
