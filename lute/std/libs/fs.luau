local fs = require("@lute/fs")

local pathlib = require("@std/path")
local win32paths = require("@std/path/win32")
local sys = require("@std/system")

--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local deque = require("@batteries/collections/deque")

local fslib = {}

export type HandleMode = fs.HandleMode
export type File = fs.FileHandle
export type FileType = fs.FileType
export type FileMetadata = fs.FileMetadata
export type DirectoryEntry = fs.DirectoryEntry
export type WatchHandle = fs.WatchHandle
export type WatchEvent = fs.WatchEvent

type Pathlike = pathlib.Pathlike
type Path = pathlib.Path
type win32path = win32paths.Path

export type CreateDirectoryOptions = {
	makeParents: boolean?,
}

export type RemoveDirectoryOptions = {
	recursive: boolean?,
}

export type WalkOptions = {
	recursive: boolean?,
}

type Watcher = {
	next: (Watcher) -> WatchEvent?,
	close: (self: Watcher) -> (),
}

function fslib.open(path: Pathlike, mode: HandleMode?): File
	return fs.open(pathlib.format(path), mode)
end

function fslib.read(file: File): string
	return fs.read(file)
end

function fslib.write(file: File, contents: string): ()
	return fs.write(file, contents)
end

function fslib.close(file: File): ()
	return fs.close(file)
end

function fslib.remove(path: Pathlike): ()
	return fs.remove(pathlib.format(path))
end

function fslib.metadata(path: Pathlike): FileMetadata
	return fs.stat(pathlib.format(path))
end

function fslib.type(path: Pathlike): FileType
	return fs.type(pathlib.format(path))
end

function fslib.link(src: Pathlike, dest: Pathlike): ()
	return fs.link(pathlib.format(src), pathlib.format(dest))
end

function fslib.symbolicLink(src: Pathlike, dest: Pathlike): ()
	return fs.symlink(pathlib.format(src), pathlib.format(dest))
end

--- Iterator function that yields filename and event pairs when changes occur in the watched path.
--- Also provides a `close` method to stop watching.
--- Note: for loops do not support yielding generalized iterators, so we cannot use fs.watch as `for _ in fs.watch(...) do` directly. A while loop can be used instead. See example/watch_directory.luau for usage.
function fslib.watch(path: Pathlike): Watcher
	-- In the future this could be written with explicit instantiation syntax
	-- as in:
	--
	--	deque.new<<{ filename: path, event: watchevent }>>()
	local deq = deque.new(nil :: { filename: Path, event: WatchEvent }?)
	local handle = fs.watch(pathlib.format(path), function(filename, event)
		deq:pushback({ filename = pathlib.parse(filename), event = event })
	end)

	return {
		next = function(_self: Watcher): WatchEvent?
			if not deq:peekfront() then
				return nil
			end
			local item = deq:popfront()
			assert(item)
			return item.event
		end,
		close = function(_self: Watcher): ()
			if handle then
				handle:close()
			end
		end,
	}
end

function fslib.exists(path: Pathlike): boolean
	return fs.exists(pathlib.format(path))
end

function fslib.copy(src: Pathlike, dest: Pathlike): ()
	return fs.copy(pathlib.format(src), pathlib.format(dest))
end

function fslib.listDirectory(path: Pathlike): { DirectoryEntry }
	return fs.listdir(pathlib.format(path))
end

function fslib.readFileToString(filepath: Pathlike): string
	local f = fs.open(pathlib.format(filepath), "r")
	local contents = fs.read(f)
	fs.close(f)
	return contents
end

function fslib.writeStringToFile(filepath: Pathlike, contents: string): ()
	local f = fs.open(pathlib.format(filepath), "w+")
	fs.write(f, contents)
	fs.close(f)
end

function fslib.createDirectory(path: Pathlike, options: CreateDirectoryOptions?): ()
	if options and options.makeParents then
		local parsed = pathlib.parse(path)
		local parts: { string } = parsed.parts

		local subdir: Pathlike = "."
		if pathlib.isAbsolute(path) then
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

function fslib.removeDirectory(path: Pathlike, options: RemoveDirectoryOptions?): ()
	if options and options.recursive then
		-- Recursively delete all contents first
		if fslib.exists(path) and fslib.type(path) == "dir" then
			local entries = fslib.listDirectory(path)
			for _, entry in entries do
				local entryPath = pathlib.join(path, entry.name)
				if entry.type == "dir" then
					fslib.removeDirectory(entryPath, { recursive = true })
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
function fslib.walk(path: Pathlike, options: WalkOptions?): () -> Path?
	local queue: { Path } = { pathlib.parse(path) }
	local recursive = if options then options.recursive else false

	return function()
		while #queue > 0 do
			local current = table.remove(queue, 1)
			if not current then
				return nil
			end

			if fslib.type(current) == "dir" and recursive then
				local entries = fslib.listDirectory(current)
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
