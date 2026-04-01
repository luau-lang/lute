local fs = require("@lute/fs")
local process = require("@lute/process")

local ignore = require("./ignore")
local path = require("@std/path")
local stringext = require("@std/stringext")
local tableext = require("@std/tableext")

local function traverseDirectoryRecursive(
	directory: path.Path,
	ignoreResolver: ignore.IgnoreResolver,
	verbose: boolean?
): { path.Path }
	local results = {}

	for _, entry in fs.listdir(path.format(directory)) do
		local fullPath = path.join(directory, entry.name)

		if entry.type == "dir" then
			if ignoreResolver:isIgnoredDirectory(fullPath) then
				if verbose then
					print("Skipping", fullPath)
				end
				continue
			end

			tableext.extend(results, traverseDirectoryRecursive(fullPath, ignoreResolver, verbose))
		else
			-- TODO: allow customisation of the filter when traversing a directory. e.g., globs? file endings? ignore paths?
			if stringext.hasSuffix(entry.name, ".luau") or stringext.hasSuffix(entry.name, ".lua") then
				if ignoreResolver:isIgnoredFile(fullPath) then
					if verbose then
						print("Skipping", fullPath)
					end
					continue
				end
				table.insert(results, fullPath)
			elseif verbose then
				print(`Skipping non-Luau file '{fullPath}'`)
			end
		end
	end

	return results
end

local function getSourceFiles(paths: { string }, verbose: boolean?): { path.Path }
	local files = {}

	local ignoreResolver = ignore.new()

	for _, filepath in paths do
		local pathObj = path.parse(filepath)

		if not path.isabsolute(pathObj) then
			pathObj = path.resolve(process.cwd(), pathObj)
		end

		filepath = path.format(pathObj)
		if verbose then
			print(filepath)
		end
		if fs.type(filepath) == "dir" then
			tableext.extend(files, traverseDirectoryRecursive(pathObj, ignoreResolver, verbose))
		else
			table.insert(files, pathObj)
		end
	end

	return files
end

return {
	getSourceFiles = getSourceFiles,
}
