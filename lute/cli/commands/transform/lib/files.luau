local fs = require("@lute/fs")
local process = require("@lute/process")

local ignore = require("./ignore")
local path = require("./path")
local strings = require("./strings")

local function extend<T>(tbl: { T }, other: { T })
	for _, entry in other do
		table.insert(tbl, entry)
	end
end

local function traverseDirectoryRecursive(directory: string, ignoreResolver: ignore.IgnoreResolver): { string }
	local results = {}

	for _, entry in fs.listdir(directory) do
		local fullPath = path.joinPath(directory, entry.name)

		if entry.type == "dir" then
			if ignoreResolver:isIgnoredDirectory(fullPath) then
				print("Skipping", fullPath)
				continue
			end

			extend(results, traverseDirectoryRecursive(fullPath, ignoreResolver))
		else
			-- TODO: allow customisation of the filter when traversing a directory. e.g., globs? file endings? ignore paths?
			if strings.endsWith(entry.name, ".luau") or strings.endsWith(entry.name, ".lua") then
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

local function getSourceFiles(paths: { string }): { string }
	local files = {}

	local ignoreResolver = ignore.new()

	for _, filepath in paths do
		if not path.isAbsolute(filepath) then
			filepath = path.joinPath(process.cwd(), filepath)
		end

		print(filepath)
		if fs.type(filepath) == "dir" then
			extend(files, traverseDirectoryRecursive(filepath, ignoreResolver))
		else
			table.insert(files, filepath)
		end
	end

	return files
end

return {
	getSourceFiles = getSourceFiles,
}
