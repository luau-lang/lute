local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")
local ignore = require("../lib/ignore")

local function istestfile(filename: string): boolean
	return stringext.hasSuffix(filename, ".test.luau") or stringext.hasSuffix(filename, ".spec.luau")
end

local function issnapfile(filename: string): boolean
	return stringext.hasSuffix(filename, ".snap.luau")
end

local function findfiles(paths: { string }, predicate: (string) -> boolean): { path.Path }
	local files = {}
	local resolver = ignore.new()

	local function walk(directory: path.Path)
		for _, entry in fs.listDirectory(directory) do
			local fullPath = path.join(directory, entry.name)
			if entry.type == "dir" then
				if not resolver:isIgnoredDirectory(fullPath) then
					walk(fullPath)
				end
			elseif predicate(entry.name) and not resolver:isIgnoredFile(fullPath) then
				table.insert(files, fullPath)
			end
		end
	end

	for _, p in paths do
		local rooted = path.resolve(p)
		if fs.type(rooted) == "dir" then
			walk(rooted)
		elseif predicate(path.format(rooted)) then
			table.insert(files, rooted)
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
