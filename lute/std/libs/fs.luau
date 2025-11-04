--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local fs = require("@lute/fs")
local pathlib = require("@std/path")

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
		local parts: { string } = pathlib.parse(path).parts

		local subdir: pathlike = "."
		if pathlib.isabsolute(path) then
			subdir = pathlib.format({ absolute = true, parts = {} })
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

return table.freeze(fslib)
