--!strict

local crypto = require("@lute/crypto")
local fs = require("@lute/fs")
local process = require("@lute/process")
local system = require("@lute/system")

local cli = require("@batteries/cli")
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
args:add("luthier", "positional", { help = "the luthier script", required = true }) -- should this be handled automatically?
args:add("subcommand", "positional", { help = "command to execute", required = true })
args:add("target", "positional", { help = "the thing to build or run", required = true })
args:add("verbose", "flag", { help = "show verbose compile output", aliases = { "v" } })
args:add("config", "option", { help = "configuration (default is debug)", default = "debug" })
args:add("clean", "flag", { help = "perform a clean build" })
args:add("which", "flag", { help = "print out the path to the compiled binary and exit", aliases = { "w" } })
args:add("cxx-compiler", "option", { help = "C++ compiler to use" })
args:add("c-compiler", "option", { help = "C compiler to use" })

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
	return args:get("config")
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
		table.sort(contents, function(a, b)
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

local function getStdLibHash(): string
	local libsPath = projectRelative("lute", "std", "libs")
	local libs = fs.listdir(libsPath)

	local toHash = ""

	traverseFileTree(libsPath, function(path, relativePath)
		if safeFsType(path) == "file" then
			toHash ..= "./" .. relativePath
			toHash ..= fs.readfiletostring(path)
		end
	end)

	local digest = crypto.digest(crypto.hash.blake2b256, toHash)
	return hexify(digest)
end

local function isGeneratedStdLibUpToDate(): boolean
	local hashFile = projectRelative("lute", "std", "src", "generated", "hash.txt")

	if safeFsType(hashFile) ~= "file" then
		return false
	end

	local hash = fs.readfiletostring(hashFile)

	return hash == getStdLibHash()
end

local function writeLines(file, lines: { string })
	fs.write(file, table.concat(lines, "\n") .. "\n")
end

local function generateStdLibFilesIfNeeded()
	local generatedPath = projectRelative("lute", "std", "src", "generated")
	pcall(fs.mkdir, generatedPath)

	if isGeneratedStdLibUpToDate() then
		return
	end

	print("Generating code for @std libraries, files are out of date.")

	local cpp = fs.open(joinPath(generatedPath, "modules.cpp"), "w+")

	writeLines(cpp, {
		"// This file is auto-generated by luthier.luau. Do not edit.",
		"// Instead, you should modify the source files in `std/libs`.",
		"",
		'#include "modules.h"',
		"",
		"constexpr std::pair<std::string_view, std::string_view> lutestdlib[] = {",
	})

	local libsPath = projectRelative("lute", "std", "libs")
	local libs = fs.listdir(libsPath)
	local numItems = 0

	traverseFileTree(libsPath, function(path, relativePath)
		if #relativePath == 0 then
			return -- Skip the root directory
		end

		local aliasedPath = "@std/" .. relativePath

		if safeFsType(path) == "file" then
			local libSrc = fs.readfiletostring(path)
			fs.write(cpp, `\n    \{"{aliasedPath}", R"({libSrc})"},\n`)
		end

		if safeFsType(path) == "dir" then
			fs.write(cpp, `\n    \{"{aliasedPath}", "#directory"},\n`)
		end

		numItems += 1
	end)

	fs.write(cpp, "};\n")
	fs.close(cpp)

	local header = fs.open(joinPath(generatedPath, "modules.h"), "w+")
	writeLines(header, {
		"// This file is auto-generated by luthier.luau. Do not edit.",
		"#pragma once",
		"",
		"#include <string_view>",
		"#include <utility>",
		"",
		`extern const std::pair<std::string_view, std::string_view> lutestdlib[{numItems}];`,
	})
	fs.close(header)

	local hash = fs.open(joinPath(generatedPath, "hash.txt"), "w+")
	fs.write(hash, getStdLibHash())
	fs.close(hash)
end

local function getCliCommandsHash()
	local libsPath = projectRelative("lute", "cli", "commands")
	local toHash = ""

	traverseFileTree(libsPath, function(path, relativePath)
		if safeFsType(path) == "file" then
			toHash ..= "./" .. relativePath
			toHash ..= fs.readfiletostring(path)
		end
	end)

	local digest = crypto.digest(crypto.hash.blake2b256, toHash)
	return hexify(digest)
end

local function isGeneratedCliCommandsUpToDate()
	local hashFile = projectRelative("lute", "cli", "generated", "hash.txt")

	if safeFsType(hashFile) ~= "file" then
		return false
	end

	local hash = fs.readfiletostring(hashFile)

	return hash == getCliCommandsHash()
end

local function generateCliCommandsFilesIfNeeded()
	local generatedPath = projectRelative("lute", "cli", "generated")
	pcall(fs.mkdir, generatedPath)

	if isGeneratedCliCommandsUpToDate() then
		return
	end

	print("Generating code for CLI commands, files are out of date.")

	local cpp = fs.open(joinPath(generatedPath, "commands.cpp"), "w+")

	writeLines(cpp, {
		"// This file is auto-generated by luthier.luau. Do not edit.",
		"// Instead, you should modify the source files in `cli/commands`.",
		"",
		'#include "commands.h"',
		"",
		"constexpr std::pair<std::string_view, std::string_view> luteclicommands[] = {",
	})

	local libsPath = projectRelative("lute", "cli", "commands")
	local numItems = 0

	traverseFileTree(libsPath, function(path, relativePath)
		if #relativePath == 0 then
			return -- Skip the root directory
		end

		local aliasedPath = "@cli/" .. relativePath

		if safeFsType(path) == "file" then
			local libSrc = fs.readfiletostring(path)
			fs.write(cpp, `\n    \{"{aliasedPath}", R"({libSrc})"},\n`)
		end

		if safeFsType(path) == "dir" then
			fs.write(cpp, `\n    \{"{aliasedPath}", "#directory"},\n`)
		end

		numItems += 1
	end)

	fs.write(cpp, "};\n")
	fs.close(cpp)

	local header = fs.open(joinPath(generatedPath, "commands.h"), "w+")
	writeLines(header, {
		"// This file is auto-generated by luthier.luau. Do not edit.",
		"#pragma once",
		"",
		"#include <string_view>",
		"#include <utility>",
		"",
		`extern const std::pair<std::string_view, std::string_view> luteclicommands[{numItems}];`,
	})
	fs.close(header)

	local hash = fs.open(joinPath(generatedPath, "hash.txt"), "w+")
	fs.write(hash, getCliCommandsHash())
	fs.close(hash)
end

local function generateFilesIfNeeded()
	generateStdLibFilesIfNeeded()
	generateCliCommandsFilesIfNeeded()
end

local function getExePath(): string
	local target = args:get("target")
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

local function build()
	local exeName = getExeName(args:get("target"))
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
		call({ "rm", "-rf", projectPath })
	end

	local configArgs =
		{ "-G=Ninja", "-B " .. projectPath, "-DCMAKE_BUILD_TYPE=" .. config, "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }

	if args:get("cxx-compiler") then
		table.insert(configArgs, "-DCMAKE_CXX_COMPILER=" .. args:get("cxx-compiler"))
	end

	if args:get("c-compiler") then
		table.insert(configArgs, "-DCMAKE_C_COMPILER=" .. args:get("c-compiler"))
	end

	return configArgs
end

local function readTuneFile(path: string): Tune
	return toml.deserialize(fs.readasync(path))
end

local function check(exitCode: number)
	if exitCode ~= 0 then
		error("Command failed with exit code " .. exitCode)
	end
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

local function fetchDependencies(): number
	local files = fs.listdir(projectRelative("extern"))

	for _, file in files do
		if string.find(file.name, "%.tune$") then
			local dependencyInfo = readTuneFile(projectRelative("extern", file.name))
			check(fetchDependency(dependencyInfo))
		end
	end

	return 0
end

local function configure()
	local cmd = { "cmake" }
	local arguments = getConfigureArguments()

	table.move(arguments, 1, #arguments, 2, cmd)

	check(fetchDependencies())
	return call(cmd)
end

local function run()
	local cmd = { getExePath() }
	local forwarded = args:forwarded() or {}

	table.move(forwarded, 1, #forwarded, 2, cmd)

	return call(cmd)
end

args:parse({ ... })

cwd = getSourceRoot()

if args:has("help") then
	print(args:help())
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
elseif subcommand == "configure" or subcommand == "tune" then
	generateFilesIfNeeded()
	exitCode = configure()
elseif subcommand == "build" or subcommand == "craft" then
	generateFilesIfNeeded()

	if not projectPathExists() then
		check(configure())
	end

	exitCode = build()
elseif subcommand == "run" or subcommand == "play" then
	generateFilesIfNeeded()

	if not projectPathExists() then
		check(configure())
	end

	if not exeExists() then
		check(build())
	end

	exitCode = run()
else
	error("Unknown subcommand " .. subcommand)
end

if exitCode ~= 0 then
	error("Command failed with exit code " .. exitCode)
end
