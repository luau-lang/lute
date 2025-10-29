--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local fs = require("@lute/fs")
local pathlib = require("@std/path")

export type handlemode = fs.HandleMode
export type filehandle = fs.FileHandle
export type filetype = fs.FileType
export type filemetadata = fs.FileMetadata
export type directoryentry = fs.DirectoryEntry
export type watchhandle = fs.WatchHandle
export type watchevent = fs.WatchEvent
export type pathlike = pathlib.pathlike

export type createdirectoryoptions = {
	makeparents: boolean,
}

local function open(path: pathlike, mode: handlemode?): filehandle
	return fs.open(pathlib.format(path), mode)
end

local function read(handle: filehandle): string
	return fs.read(handle)
end

local function write(handle: filehandle, contents: string): ()
	return fs.write(handle, contents)
end

local function close(handle: filehandle): ()
	return fs.close(handle)
end

local function remove(path: pathlike): ()
	return fs.remove(pathlib.format(path))
end

local function stat(path: pathlike): filemetadata
	return fs.stat(pathlib.format(path))
end

local function type(path: pathlike): filetype
	return fs.type(pathlib.format(path))
end

local function link(src: pathlike, dest: pathlike): ()
	return fs.link(pathlib.format(src), pathlib.format(dest))
end

local function symlink(src: pathlike, dest: pathlike): ()
	-- make sure our path is absolute path for symlink and if your os is
	return fs.symlink(pathlib.format(src), pathlib.format(dest))
end

local function watch(path: pathlike, callback: (filename: pathlike, event: watchevent) -> ()): watchhandle
	return fs.watch(pathlib.format(path), callback)
end

local function exists(path: pathlike): boolean
	return fs.exists(pathlib.format(path))
end

local function copy(src: pathlike, dest: pathlike): ()
	return fs.copy(pathlib.format(src), pathlib.format(dest))
end

local function listdir(path: pathlike): { directoryentry }
	return fs.listdir(pathlib.format(path))
end

local function rmdir(path: pathlike): ()
	return fs.rmdir(pathlib.format(path))
end

local function readfiletostring(filepath: pathlike): string
	return fs.readfiletostring(pathlib.format(filepath))
end

local function writestringtofile(filepath: pathlike, contents: string): ()
	return fs.writestringtofile(pathlib.format(filepath), contents)
end

local function readasync(filepath: pathlike): string
	return fs.readasync(pathlib.format(filepath))
end

local function createdirectory(path: pathlike, options: createdirectoryoptions): ()
	if options.makeparents then
		local parts: { string } = pathlib.parse(path).parts

		local subdir: pathlike = "."
		if pathlib.isabsolute(path) then
			subdir = pathlib.format({ absolute = true, parts = {} })
		end

		for _, part in parts do
			subdir = pathlib.join(subdir, part)
			if not exists(subdir) then
				fs.mkdir(pathlib.format(subdir))
			end
		end
	else
		fs.mkdir(pathlib.format(path))
	end
end

return table.freeze({
	open = open,
	read = read,
	write = write,
	close = close,
	remove = remove,
	stat = stat,
	type = type,
	link = link,
	symlink = symlink,
	watch = watch,
	exists = exists,
	copy = copy,
	listdir = listdir,
	rmdir = rmdir,
	readfiletostring = readfiletostring,
	writestringtofile = writestringtofile,
	readasync = readasync,
	createdirectory = createdirectory,
})
