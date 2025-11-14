--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local fs = require("@lute/fs")
local pathlib = require("@std/path")
local sys = require("@std/system")

local fslib = {}

export type handlemode = fs.HandleMode
export type filehandle = fs.FileHandle
export type filetype = fs.FileType
export type filemetadata = fs.FileMetadata
export type directoryentry = fs.DirectoryEntry
export type watchhandle = fs.WatchHandle
export type watchevent = fs.WatchEvent
export type pathlike = pathlib.pathlike

export type createdirectoryoptions = {
	makeparents: boolean?,
}

export type walkdirectoryoptions = {
	recursive: boolean?,
}

function fslib.open(path: pathlike, mode: handlemode?): filehandle
	return fs.open(pathlib.format(path), mode)
end

function fslib.read(handle: filehandle): string
	return fs.read(handle)
end

function fslib.write(handle: filehandle, contents: string): ()
	return fs.write(handle, contents)
end

function fslib.close(handle: filehandle): ()
	return fs.close(handle)
end

function fslib.remove(path: pathlike): ()
	return fs.remove(pathlib.format(path))
end

function fslib.stat(path: pathlike): filemetadata
	return fs.stat(pathlib.format(path))
end

function fslib.type(path: pathlike): filetype
	return fs.type(pathlib.format(path))
end

function fslib.link(src: pathlike, dest: pathlike): ()
	return fs.link(pathlib.format(src), pathlib.format(dest))
end

function fslib.symlink(src: pathlike, dest: pathlike): ()
	return fs.symlink(pathlib.format(src), pathlib.format(dest))
end

function fslib.watch(path: pathlike, callback: (filename: pathlike, event: watchevent) -> ()): watchhandle
	return fs.watch(pathlib.format(path), callback)
end

function fslib.exists(path: pathlike): boolean
	return fs.exists(pathlib.format(path))
end

function fslib.copy(src: pathlike, dest: pathlike): ()
	return fs.copy(pathlib.format(src), pathlib.format(dest))
end

function fslib.listdir(path: pathlike): { directoryentry }
	return fs.listdir(pathlib.format(path))
end

function fslib.rmdir(path: pathlike): ()
	return fs.rmdir(pathlib.format(path))
end

function fslib.readfiletostring(filepath: pathlike): string
	return fs.readfiletostring(pathlib.format(filepath))
end

function fslib.writestringtofile(filepath: pathlike, contents: string): ()
	return fs.writestringtofile(pathlib.format(filepath), contents)
end

function fslib.readasync(filepath: pathlike): string
	return fs.readasync(pathlib.format(filepath))
end

function fslib.createdirectory(path: pathlike, options: createdirectoryoptions?): ()
	if options and options.makeparents then
		local parsed = pathlib.parse(path)
		local parts: { string } = parsed.parts

		local subdir: pathlike = "."
		if pathlib.isabsolute(path) then
			if sys.win32 then
				-- Windows path - get the drive root like "C:\"
				subdir = pathlib.win32.drive(parsed)
			else
				-- POSIX absolute path - start from root "/"
				subdir = pathlib.format({ absolute = true, parts = {} })
			end
		end

		for _, part in parts do
			subdir = pathlib.join(subdir, part)
			if not fslib.exists(subdir) then
				fs.mkdir(pathlib.format(subdir))
			end
		end
	else
		fs.mkdir(pathlib.format(path))
	end
end

local function walkdir(path: pathlike, options: walkdirectoryoptions?): () -> pathlike?
	local queue = { path }
	local recursive = options and options.recursive or false

	return function()
		while #queue > 0 do
			local current = table.remove(queue, 1)
			if not current then
				return nil
			end

			if fslib.type(current) == "dir" and recursive then
				local entries = fslib.listdir(current)
				for _, entry in entries do
					local fullPath = pathlib.format(pathlib.join(current, entry.name))
					table.insert(queue, fullPath)
				end
			end

			return current
		end

		return nil
	end
end

--[[
	Walks the directory at the given path.

	Parameters:
		path (pathlike): The path to the directory to walk.
		options (walkdirectoryoptions?): Optional settings for walking the directory.
			- recursive (boolean?): If true, walks directories recursively. Default is false.

	Returns:
		A function that, when called, returns the next pathlike in the directory walk, or nil when done.

	Example:
		local walker = fslib.walk("some/directory", { recursive = true })
		while true do
			local filepath = walker()
			if not filepath then
				break
			end
			print(filepath)
		end
	
	Note: for loops do not support yielding generalized iterators, so we cannot use fs.walk as `for path in fs.walk(...) do` directly. A while loop can be used instead.
]]
--
function fslib.walk(path: pathlike, options: walkdirectoryoptions?): () -> pathlike?
	return walkdir(path, options)
end

return table.freeze(fslib)
