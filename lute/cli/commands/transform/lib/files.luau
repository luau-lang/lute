local fs = require("@lute/fs")
local process = require("@lute/process")

local ignore = require("./ignore")
local path = require("@std/path")
local string = require("@std/string")
local tbl = require("@std/table")

local function traverseDirectoryRecursive(directory: path.path, ignoreResolver: ignore.IgnoreResolver): { path.path }
	local results = {}

	for _, entry in fs.listdir(path.format(directory)) do
		local fullPath = path.join(directory, entry.name)

		if entry.type == "dir" then
			if ignoreResolver:isIgnoredDirectory(fullPath) then
				print("Skipping", fullPath)
				continue
			end

			tbl.extend(results, traverseDirectoryRecursive(fullPath, ignoreResolver))
		else
			-- TODO: allow customisation of the filter when traversing a directory. e.g., globs? file endings? ignore paths?
			if string.endswith(entry.name, ".luau") or string.endswith(entry.name, ".lua") then
				if ignoreResolver:isIgnoredFile(fullPath) then
					print("Skipping", fullPath)
					continue
				end
				table.insert(results, fullPath)
			end
		end
	end

	return results
end

local function getSourceFiles(paths: { string }): { path.path }
	local files = {}

	local ignoreResolver = ignore.new()

	for _, filepath in paths do
		local pathObj = path.parse(filepath)

		if not path.isabsolute(pathObj) then
			pathObj = path.join(process.cwd(), pathObj)
		end

		filepath = path.format(pathObj)
		print(filepath)
		if fs.type(filepath) == "dir" then
			tbl.extend(files, traverseDirectoryRecursive(pathObj, ignoreResolver))
		else
			table.insert(files, pathObj)
		end
	end

	return files
end

return {
	getSourceFiles = getSourceFiles,
}
