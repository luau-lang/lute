--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local deque = require("@batteries/collections/deque")
local fs = require("@lute/fs")
local pathlib = require("@std/path")
local sys = require("@std/system")
local win32paths = require("@std/path/win32")

local fslib = {}

export type handlemode = fs.HandleMode
export type file = fs.FileHandle
export type type = fs.FileType
export type metadata = fs.FileMetadata
export type directoryentry = fs.DirectoryEntry
export type watchhandle = fs.WatchHandle
export type watchevent = fs.WatchEvent

type pathlike = pathlib.pathlike
type path = pathlib.path
type win32path = win32paths.path

export type createdirectoryoptions = {
	makeparents: boolean?,
}

export type removedirectoryoptions = {
	recursive: boolean?,
}

export type walkoptions = {
	recursive: boolean?,
}

type watcher = {
	next: (watcher) -> watchevent?,
	close: (self: watcher) -> (),
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

function fslib.type(path: pathlike): type
	return fs.type(pathlib.format(path))
end

function fslib.link(src: pathlike, dest: pathlike): ()
	return fs.link(pathlib.format(src), pathlib.format(dest))
end

function fslib.symboliclink(src: pathlike, dest: pathlike): ()
	return fs.symlink(pathlib.format(src), pathlib.format(dest))
end

--- Iterator function that yields filename and event pairs when changes occur in the watched path.
--- Also provides a `close` method to stop watching.
--- Note: for loops do not support yielding generalized iterators, so we cannot use fs.watch as `for _ in fs.watch(...) do` directly. A while loop can be used instead. See example/watch_directory.luau for usage.
function fslib.watch(path: pathlike): watcher
	-- In the future this could be written with explicit instantiation syntax
	-- as in:
	--
	--	deque.new<<{ filename: path, event: watchevent }>>()
	local deq = deque.new(nil :: { filename: path, event: watchevent }?)
	local handle = fs.watch(pathlib.format(path), function(filename, event)
		deq:pushback({ filename = pathlib.parse(filename), event = event })
	end)

	return {
		next = function(_self: watcher): watchevent?
			if not deq:peekfront() then
				return nil
			end
			local item = deq:popfront()
			assert(item)
			return item.event
		end,
		close = function(_self: watcher): ()
			if handle then
				handle:close()
			end
		end,
	}
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
	local f = fs.open(pathlib.format(filepath), "r")
	local contents = fs.read(f)
	fs.close(f)
	return contents
end

function fslib.writestringtofile(filepath: pathlike, contents: string): ()
	local f = fs.open(pathlib.format(filepath), "w+")
	fs.write(f, contents)
	fs.close(f)
end

function fslib.createdirectory(path: pathlike, options: createdirectoryoptions?): ()
	if options and options.makeparents then
		local parsed = pathlib.parse(path)
		local parts: { string } = parsed.parts

		local subdir: pathlike = "."
		if pathlib.isabsolute(path) then
			if sys.win32 then
				-- Windows path - get the drive root like "C:\"
				subdir = pathlib.win32.drive(parsed :: win32path)
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

--- Note: for loops do not support yielding generalized iterators, so we cannot use fs.walk as `for path in fs.walk(...) do` directly. A while loop can be used instead. See example/walk_directory.luau for usage.
function fslib.walk(path: pathlike, options: walkoptions?): () -> path?
	local queue: { path } = { pathlib.parse(path) }

	return function()
		while #queue > 0 do
			local current = table.remove(queue, 1)
			if not current then
				return nil
			end

			if fslib.type(current) == "dir" and options and options.recursive then -- LUAUFIX: error on options.recursive because it thinks options could still be nil
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
