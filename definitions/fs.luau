local fs = {}

export type FileHandle = {
	fd: number,
	err: number,
}

export type FileType = "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown"

export type DirectoryEntry = {
	name: string,
	type: FileType,
}

export type WatchHandle = {
	close: (self: WatchHandle) -> (),
}

export type WatchEvent = {
	change: boolean,
	rename: boolean,
}

function fs.open(path: string): FileHandle
	error("not implemented")
end

function fs.read(handle: FileHandle): string
	error("not implemented")
end

function fs.write(handle: FileHandle, contents: string): ()
	error("not implemented")
end

function fs.close(handle: FileHandle): ()
	error("not implemented")
end

function fs.remove(path: string): ()
	error("not implemented")
end

function fs.type(path: string): FileType
	error("not implemented")
end

function fs.mkdir(path: string): ()
	error("not implemented")
end

function fs.link(src: string, dest: string): ()
	error("not implemented")
end

function fs.symlink(src: string, dest: string): ()
	error("not implemented")
end

function fs.watch(path: string, callback: (filename: string, event: WatchEvent) -> ()): WatchHandle
	error("not implemented")
end

function fs.exists(path: string): boolean
	error("not implemented")
end

function fs.copy(src: string, dest: string): ()
	error("not implemented")
end

function fs.listdir(path: string): { DirectoryEntry }
	error("not implemented")
end

function fs.rmdir(path: string): ()
	error("not implemented")
end

function fs.readfiletostring(filepath: string): string
	error("not implemented")
end

function fs.writestringtofile(filepath: string, contents: string): ()
	error("not implemented")
end

function fs.readasync(filepath: string): string
	error("not implemented")
end

return fs
