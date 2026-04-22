local fs = require("@std/fs")
local process = require("@std/process")
local path = require("@std/path")
local luau = require("@std/luau")
local strext = require("@std/stringext")

local difftext = require("@batteries/difftext")

local snapty = require("./types")

-- Derive the .snap artifact path from a .snap.luau file path.
-- e.g. /foo/bar.snap.luau -> /foo/bar.snap
local function artifactPath(filepath: path.Path): string
	local f = path.format(filepath)
	assert(strext.hasSuffix(f, ".snap.luau"), `expected {f} to have suffix .snap.luau`)
	return strext.removeSuffix(f, ".luau") -- strips ".luau"
end

local function retrieveConfiguration(directory: string): snapty.SnapshotConfiguration?
	local configFile = path.join(directory, "snap.config.luau")
	if not fs.exists(configFile) then
		return nil
	end

	local ok, v = pcall(luau.loadModule, configFile, nil)
	if not ok then
		error("Failed to load snapshot testing configuration at path: " .. directory)
	end

	return v
end

local function getCommandArgs(
	execpath: string,
	filepath: string,
	configuration: snapty.SnapshotConfiguration?,
	artifactPath: string
)
	local args = { execpath }
	local testname = strext.removeSuffix(artifactPath, ".snap")
	if not configuration then
		table.insert(args, filepath)
		return args
	end

	-- Per-test override takes priority over base config
	local config: snapty.TestConfiguration? = nil
	if configuration.overrides ~= nil and configuration.overrides[testname] ~= nil then
		config = configuration.overrides[testname]
	elseif configuration.config ~= nil then
		config = configuration.config
	end

	-- Config args go between execpath and filepath (e.g. lute lint --flags <filepath>)
	if config then
		for _, arg in config.args do
			table.insert(args, arg)
		end
	end

	table.insert(args, filepath)
	return args
end

local function posixify(str)
	local posixy, _ = string.gsub(str, [[\]], "/")
	return posixy
end

local function normalizeSnapshotOutput(output: string, normalizedCwd: string): string
	local noCrlf, _ = string.gsub(output, "\r\n", "\n")
	local nobackslash = posixify(noCrlf)
	local replacedCwd, _ = string.gsub(nobackslash, normalizedCwd, "<ROOT>")
	return replacedCwd
end

local runner = {}

function runner.runsnapshots(files: { path.Path }): snapty.snapresult
	local result: snapty.snapresult = {
		passed = {},
		failed = {},
		new = {},
	}

	local execpath = path.format(process.execPath())

	-- Compute the normalized current working directory exactly once
	--[[
		Paths can have '.' characters in them, but gsub takes patterns as arguments and a '.' will match any single character.
		E.g. Interpreting "/foo/bar.baz" as a pattern, will match "/foo/bar[any char]baz".
		We need to replace any explicit '.' in a string that will be used as a pattern, with the escaped '.'
		Gsub takes two patterns as its second and third argument, so we'll need to replace all '.' in the string(represented by the pattern '%.')
		with the '.' matching pattern '%.'(itself represented by escaping the %, '%%.').
	]]
	--
	local cwd = posixify(path.format(process.cwd()))
	cwd, _ = string.gsub(cwd, "%.", "%%.")

	local configCache: { [string]: snapty.SnapshotConfiguration | "missing" } = {}
	for _, filepath in files do
		local configuration: snapty.SnapshotConfiguration? = nil
		local directory = path.dirname(filepath)
		local maybeConfig = configCache[directory]
		if maybeConfig == nil then
			local ok, conf = pcall(retrieveConfiguration, directory)
			if not ok then
				-- Something went wrong loading this module
				break
			end

			-- it doesn't exist
			if not conf then
				configCache[directory] = "missing"
			else
				configCache[directory] = conf
				configuration = conf
			end
		elseif maybeConfig ~= "missing" then
			configuration = maybeConfig
		end

		local artifactpath = artifactPath(filepath)
		local args = getCommandArgs(execpath, path.format(filepath), configuration, artifactpath)

		local proc = process.run(args)
		local actual = normalizeSnapshotOutput(proc.stdout, cwd)

		if not fs.exists(artifactpath) then
			-- No artifact file yet — this is a new snapshot
			table.insert(result.new, {
				filepath = filepath,
				artifactpath = artifactpath,
				actual = actual,
			})
			continue
		end

		local rawExpected = fs.readFileToString(artifactpath)
		local expected, _ = string.gsub(rawExpected, "\r\n", "\n")

		if actual == expected then
			table.insert(result.passed, { filepath = filepath, artifactpath = artifactpath })
		else
			local diff = difftext.prettydiff(expected, actual, {
				detailed = true,
				includeLineNumbers = true,
			})
			table.insert(result.failed, {
				filepath = filepath,
				artifactpath = artifactpath,
				actual = actual,
				expected = expected,
				diff = diff,
				stderr = if not proc.ok then proc.stderr else "",
			})
		end
	end

	return result
end

return table.freeze(runner)
