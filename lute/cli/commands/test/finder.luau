local ps = require("@std/process")
local fs = require("@std/fs")
local path = require("@std/path")
local string = require("@std/string")

local function extend<T>(tbl: { T }, other: { T })
	for _, entry in other do
		table.insert(tbl, entry)
	end
end

local function istestfile(filename: string): boolean
	return string.endswith(filename, ".test.luau") or string.endswith(filename, ".spec.luau")
end

local function findtestfilesrec(directory: path.path): { path.path }
	local results = {}

	for _, entry in fs.listdir(path.format(directory)) do
		local fullPath = path.join(directory, entry.name)

		if entry.type == "dir" then
			extend(results, findtestfilesrec(fullPath))
		elseif istestfile(entry.name) then
			table.insert(results, fullPath)
		end
	end

	return results
end

local function findtestfiles(paths: { string }): { path.path }
	local files = {}

	for _, filepath in paths do
		local pathObj = path.parse(filepath)

		if not path.isabsolute(pathObj) then
			pathObj = path.join(path.parse(ps.cwd()), pathObj)
		end

		filepath = path.format(pathObj)

		if fs.type(filepath) == "dir" then
			extend(files, findtestfilesrec(pathObj))
		elseif istestfile(filepath) then
			table.insert(files, pathObj)
		end
	end

	return files
end

return table.freeze({ findtestfiles = findtestfiles })
