local fs = require("@std/fs")
local ps = require("@std/process")
local path = require("@std/path")
local stringext = require("@std/stringext")
local ignore = require("../lib/ignore")

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
	local ignoreResolver = ignore.new()

	local function walk(directory: path.Path)
		local entries = fs.listDirectory(directory)
		for _, entry in entries do
			stats.entriesVisited += 1
			local fullPath = path.join(directory, entry.name)

			if entry.type == "dir" then
				if ignoreResolver:isIgnoredDirectory(fullPath) then
					continue
				end
				walk(fullPath)
			elseif predicate(entry.name) then
				if ignoreResolver:isIgnoredFile(fullPath) then
					continue
				end
				table.insert(files, fullPath)
			end
		end
	end

	local cwd = ps.cwd()
	for _, p in paths do
		local rooted = if path.isAbsolute(p) then path.normalize(p) else path.normalize(path.join(cwd, p))
		local ok, ftype = pcall(fs.type, path.format(rooted))
		if ok and ftype == "dir" then
			walk(rooted)
		elseif ok and ftype == "file" then
			-- explicit file path: include it if it matches, no ignore check
			-- (user asked for it directly).
			local basename = path.basename(rooted)
			if basename and predicate(basename) then
				table.insert(files, rooted)
			end
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
