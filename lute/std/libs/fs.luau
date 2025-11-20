--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local fs = require("@lute/fs")
local pathlib = require("@std/path")
local sys = require("@std/system")

local fslib = {}

export type handlemode = fs.HandleMode
export type file = fs.FileHandle
export type filetype = fs.FileType
export type metadata = fs.FileMetadata
export type directoryentry = fs.DirectoryEntry
export type watchhandle = fs.WatchHandle
export type watchevent = fs.WatchEvent

type pathlike = pathlib.pathlike

export type createdirectoryoptions = {
	makeparents: boolean?,
}

export type removedirectoryoptions = {
	recursive: boolean?,
}

export type walkoptions = {
	recursive: boolean?,
}

function fslib.open(path: pathlike, mode: handlemode?): file
	return fs.open(pathlib.format(path), mode)
end

function fslib.read(file: file): string
	return fs.read(file)
end

function fslib.write(file: file, contents: string): ()
	return fs.write(file, contents)
end

function fslib.close(file: file): ()
	return fs.close(file)
end

function fslib.remove(path: pathlike): ()
	return fs.remove(pathlib.format(path))
end

function fslib.metadata(path: pathlike): metadata
	return fs.stat(pathlib.format(path))
end

function fslib.type(path: pathlike): filetype
	return fs.type(pathlib.format(path))
end

function fslib.link(src: pathlike, dest: pathlike): ()
	return fs.link(pathlib.format(src), pathlib.format(dest))
end

function fslib.symboliclink(src: pathlike, dest: pathlike): ()
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

function fslib.listdirectory(path: pathlike): { directoryentry }
	return fs.listdir(pathlib.format(path))
end

function fslib.readfiletostring(filepath: pathlike): string
	return fs.readfiletostring(pathlib.format(filepath))
end

function fslib.writestringtofile(filepath: pathlike, contents: string): ()
	return fs.writestringtofile(pathlib.format(filepath), contents)
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

function fslib.removedirectory(path: pathlike, options: removedirectoryoptions?): ()
	if options and options.recursive then
		-- Recursively delete all contents first
		if fslib.exists(path) and fslib.type(path) == "dir" then
			local entries = fslib.listdirectory(path)
			for _, entry in entries do
				local entryPath = pathlib.join(path, entry.name)
				if entry.type == "dir" then
					fslib.removedirectory(entryPath, { recursive = true })
				else
					fslib.remove(entryPath)
				end
			end
			fs.rmdir(pathlib.format(path))
		end
	else
		fs.rmdir(pathlib.format(path))
	end
end

-- Note: for loops do not support yielding generalized iterators, so we cannot use fs.walk as `for path in fs.walk(...) do` directly. A while loop can be used instead.
function fslib.walk(path: pathlike, options: walkoptions?): () -> path?
	local queue = { pathlib.parse(path) }

	return function()
		while #queue > 0 do
			local current = table.remove(queue, 1)
			if not current then
				return nil
			end

			if fslib.type(current) == "dir" and options and options.recursive then
				local entries = fslib.listdirectory(current)
				for _, entry in entries do
					local fullPath = pathlib.join(current, entry.name)
					table.insert(queue, fullPath)
				end
			end

			return current
		end

		return nil
	end
end

return table.freeze(fslib)
