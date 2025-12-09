local ps = require("@std/process")
local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")
local tableext = require("@std/tableext")

local function istestfile(filename: string): boolean
	return stringext.hassuffix(filename, ".test.luau") or stringext.hassuffix(filename, ".spec.luau")
end

local function findtestfiles(paths: { string }): { path.path }
	local files = {}
	local function findfiles(p: path.pathlike)
		local it = fs.walk(path.normalize(p), { recursive = true })
		local file = it()
		while file do
			if fs.type(file) ~= "dir" and istestfile(path.format(file)) then
				table.insert(files, path.normalize(file))
			end
			file = it()
		end
	end

	local cwd = ps.cwd()
	for _, p in paths do
		findfiles(path.join(cwd, p))
	end

	return files
end

return table.freeze({ findtestfiles = findtestfiles })
