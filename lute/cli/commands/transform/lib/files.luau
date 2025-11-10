local fs = require("@lute/fs")
local process = require("@lute/process")

local ignore = require("./ignore")
local path = require("@std/path")
local stringext = require("@std/stringext")
local tableext = require("@std/tableext")

local function traverseDirectoryRecursive(directory: path.path, ignoreResolver: ignore.IgnoreResolver): { path.path }
	local results = {}

	for _, entry in fs.listdir(path.format(directory)) do
		local fullPath = path.join(directory, entry.name)

		if entry.type == "dir" then
			if ignoreResolver:isIgnoredDirectory(fullPath) then
				print("Skipping", fullPath)
				continue
			end

			tableext.extend(results, traverseDirectoryRecursive(fullPath, ignoreResolver))
		else
			-- TODO: allow customisation of the filter when traversing a directory. e.g., globs? file endings? ignore paths?
			if stringext.endswith(entry.name, ".luau") or stringext.endswith(entry.name, ".lua") then
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
			tableext.extend(files, traverseDirectoryRecursive(pathObj, ignoreResolver))
		else
			table.insert(files, pathObj)
		end
	end

	return files
end

return {
	getSourceFiles = getSourceFiles,
}
