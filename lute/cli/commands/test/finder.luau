local ps = require("@std/process")
local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")

local function istestfile(filename: string): boolean
	return stringext.hassuffix(filename, ".test.luau") or stringext.hassuffix(filename, ".spec.luau")
end

local function issnapfile(filename: string): boolean
	return stringext.hassuffix(filename, ".snap.luau")
end

local function findfiles(paths: { string }, predicate: (string) -> boolean): { path.Path }
	local files = {}
	local function walk(p: path.Pathlike)
		local it = fs.walk(path.normalize(p), { recursive = true })
		local file = it()
		while file do
			if fs.type(file) ~= "dir" and predicate(path.format(file)) then
				table.insert(files, path.normalize(file))
			end
			file = it()
		end
	end

	local cwd = ps.cwd()
	for _, p in paths do
		if path.isabsolute(p) then
			walk(p)
		else
			walk(path.join(cwd, p))
		end
	end

	return files
end

local function findtestfiles(paths: { string }): { path.Path }
	return findfiles(paths, istestfile)
end

local function findsnapfiles(paths: { string }): { path.Path }
	return findfiles(paths, issnapfile)
end

return table.freeze({ findtestfiles = findtestfiles, findsnapfiles = findsnapfiles })
