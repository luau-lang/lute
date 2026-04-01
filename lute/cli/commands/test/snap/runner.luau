local process = require("@std/process")
local path = require("@std/path")
local fs = require("@std/fs")
local difftext = require("@batteries/difftext")
local strext = require("@std/stringext")
local snapty = require("./types")

-- Derive the .snap artifact path from a .snap.luau file path.
-- e.g. /foo/bar.snap.luau -> /foo/bar.snap
local function artifactpath(filepath: path.Path): string
	local f = path.format(filepath)
	assert(strext.hasSuffix(f, ".snap.luau"), `expected {f} to have suffix .snap.luau`)
	return strext.removeSuffix(f, ".luau") -- strips ".luau"
end

local function posixify(str)
	local posixy, _ = string.gsub(str, [[\]], "/")
	return posixy
end

local function normalizeSnapshotOutput(output: string, normalizedCwd: string): string
	local nobackslash = posixify(output)
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

	for _, filepath in files do
		local artifactpath = artifactpath(filepath)

		local proc = process.run({ execpath, path.format(filepath) })
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

		local expected = fs.readFileToString(artifactpath)

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
