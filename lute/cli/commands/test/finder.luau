local ps = require("@std/process")
local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")
local tableext = require("@std/tableext")

local function istestfile(filename: string): boolean
	return stringext.endswith(filename, ".test.luau") or stringext.endswith(filename, ".spec.luau")
end

local function findtestfilesrec(directory: path.path): { path.path }
	local results = {}

	for _, entry in fs.listdir(directory) do
		local fullPath = path.join(directory, entry.name)

		if entry.type == "dir" then
			tableext.extend(results, findtestfilesrec(fullPath))
		elseif istestfile(entry.name) then
			table.insert(results, path.normalize(fullPath))
		end
	end

	return results
end

local function findtestfiles(paths: { string }): { path.path }
	local files = {}
	local cwd = ps.cwd()
	for _, filepath in paths do
		local pathObj = path.parse(filepath)

		if not path.isabsolute(pathObj) then
			pathObj = path.join(cwd, pathObj)
		end

		if fs.type(pathObj) == "dir" then
			tableext.extend(files, findtestfilesrec(pathObj))
		elseif istestfile(filepath) then
			table.insert(files, path.normalize(pathObj))
		end
	end

	return files
end

return table.freeze({ findtestfiles = findtestfiles })
