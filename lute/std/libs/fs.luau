--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local fs = require("@lute/fs")
local stdPath = require("@std/path")

type HandleMode = fs.HandleMode
type FileHandle = fs.FileHandle
type FileType = fs.FileType
type FileMetadata = fs.FileMetadata
type DirectoryEntry = fs.DirectoryEntry
type WatchHandle = fs.WatchHandle
type WatchEvent = fs.WatchEvent
type pathlike = stdPath.pathlike

function open(path: pathlike, mode: HandleMode?): FileHandle
	return fs.open(stdPath.format(path), mode)
end

function read(handle: FileHandle): string
	return fs.read(handle)
end

function write(handle: FileHandle, contents: string): ()
	return fs.write(handle, contents)
end

function close(handle: FileHandle): ()
	return fs.close(handle)
end

function remove(path: pathlike): ()
	return fs.remove(stdPath.format(path))
end

function stat(path: pathlike): FileMetadata
	return fs.stat(stdPath.format(path))
end

function type(path: pathlike): FileType
	return fs.type(stdPath.format(path))
end

function mkdir(path: pathlike): ()
	return fs.mkdir(stdPath.format(path))
end

function link(src: pathlike, dest: pathlike): ()
	return fs.link(stdPath.format(src), stdPath.format(dest))
end

function symlink(src: pathlike, dest: pathlike): ()
	return fs.symlink(stdPath.format(src), stdPath.format(dest))
end

function watch(path: pathlike, callback: (filename: pathlike, event: WatchEvent) -> ()): WatchHandle
	return fs.watch(stdPath.format(path), callback)
end

function exists(path: pathlike): boolean
	return fs.exists(stdPath.format(path))
end

function copy(src: pathlike, dest: pathlike): ()
	return fs.copy(stdPath.format(src), stdPath.format(dest))
end

function listdir(path: pathlike): { DirectoryEntry }
	return fs.listdir(stdPath.format(path))
end

function rmdir(path: pathlike): ()
	return fs.rmdir(stdPath.format(path))
end

function readfiletostring(filepath: pathlike): string
	return fs.readfiletostring(stdPath.format(filepath))
end

function writestringtofile(filepath: pathlike, contents: string): ()
	return fs.writestringtofile(stdPath.format(filepath), contents)
end

function readasync(filepath: pathlike): string
	return fs.readasync(stdPath.format(filepath))
end

return table.freeze({
	open = open,
	read = read,
	write = write,
	close = close,
	remove = remove,
	stat = stat,
	type = type,
	mkdir = mkdir,
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
})
