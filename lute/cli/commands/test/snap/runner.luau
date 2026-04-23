local fs = require("@std/fs")
local luau = require("@std/luau")
local process = require("@std/process")
local path = require("@std/path")
local strext = require("@std/stringext")

local difftext = require("@batteries/difftext")

local snapty = require("./types")

-- Derive the .snap artifact path from a .snap.luau file path.
-- e.g. /foo/bar.snap.luau -> /foo/bar.snap
local function artifactFromPath(filepath: path.Path): string
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

-- Returns the argument and expected exit code if any
local function getArtifactTestConfiguration(
	execpath: string,
	filepath: string,
	configuration: snapty.SnapshotConfiguration?,
	artifactPath: string
): ({ string }, number?)
	local args = { execpath }
	local expectedExit = nil
	local pathEnd = path.basename(path.parse(artifactPath))
	local testname = ""
	if pathEnd ~= nil then
		testname = strext.removeSuffix(pathEnd, ".snap")
	end
	-- configuration here is the discovered file with snapshot testing config
	-- it also has
	if not configuration then
		table.insert(args, filepath)
		return args, expectedExit
	end

	-- Resolve args and expectedExitCode independently: override field takes priority, then base config
	local base = configuration.default
	local override = if configuration.overrides then configuration.overrides[testname] else nil

	local configArgs: { string }? = nil
	if override and override.args then
		configArgs = override.args
	elseif base and base.args then
		configArgs = base.args
	end

	local configExit: number? = nil
	if override and override.expectedExitCode then
		configExit = override.expectedExitCode
	elseif base and base.expectedExitCode then
		configExit = base.expectedExitCode
	end

	-- Config args go between execpath and filepath (e.g. lute lint --flags <filepath>)
	if configArgs then
		for _, arg in configArgs do
			table.insert(args, arg)
		end
	end
	if configExit then
		expectedExit = configExit
	end

	table.insert(args, filepath)
	return args, expectedExit
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

function runner.runsnapshots(files: { path.Path }): snapty.SnapResult
	local result: snapty.SnapResult = {
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
			local ok, confOrErr = pcall(retrieveConfiguration, directory)
			if not ok then
				-- Something went wrong loading this module, and pcall will have yielded an error for us
				print(confOrErr)
				break
			end

			local conf = confOrErr
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

		local artifactpath = artifactFromPath(filepath)
		local args, expectedExit =
			getArtifactTestConfiguration(execpath, path.format(filepath), configuration, artifactpath)

		local proc = process.run(args)
		local checkExitMismatch: snapty.ProcessExitCondition? = nil
		if expectedExit then
			checkExitMismatch = { expected = expectedExit, actual = proc.exitcode }
		end

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
		local expected = normalizeSnapshotOutput(rawExpected, cwd)
		-- A test passes when a) no exit code checking is requested and b) actual == expected
		-- It also passes when a) exit code checking is request and b) actual == expected
		local exitCodePasses = not checkExitMismatch or checkExitMismatch.expected == checkExitMismatch.actual

		if actual == expected and exitCodePasses then
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
				exitCondition = checkExitMismatch,
				diff = diff,
				stderr = if not proc.ok then proc.stderr else "",
			})
		end
	end

	return result
end

return table.freeze(runner)
