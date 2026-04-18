local ps = require("@std/process")
local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")

export type WalkStats = {
	entriesVisited: number,
}

local function istestfile(filename: string): boolean
	return stringext.hasSuffix(filename, ".test.luau") or stringext.hasSuffix(filename, ".spec.luau")
end

local function issnapfile(filename: string): boolean
	return stringext.hasSuffix(filename, ".snap.luau")
end

local function findfiles(paths: { string }, predicate: (string) -> boolean): ({ path.Path }, WalkStats)
	local files = {}
	local stats: WalkStats = { entriesVisited = 0 }

	local function walk(p: path.Pathlike)
		local it = fs.walk(path.normalize(p), { recursive = true })
		local file = it()
		while file do
			stats.entriesVisited += 1
			-- fs.walk returns both files and directories; only add matches to results.
			-- predicate rejects dir paths because they lack the test-file suffix.
			if predicate(path.format(file)) then
				table.insert(files, path.normalize(file))
			end
			file = it()
		end
	end

	local cwd = ps.cwd()
	for _, p in paths do
		if path.isAbsolute(p) then
			walk(p)
		else
			walk(path.join(cwd, p))
		end
	end

	return files, stats
end

local function findtestfiles(paths: { string }): ({ path.Path }, WalkStats)
	return findfiles(paths, istestfile)
end

local function findsnapfiles(paths: { string }): ({ path.Path }, WalkStats)
	return findfiles(paths, issnapfile)
end

return table.freeze({ findtestfiles = findtestfiles, findsnapfiles = findsnapfiles })
