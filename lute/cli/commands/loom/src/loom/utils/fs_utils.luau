local fs = require("@std/fs")

export type FileSystemInterface = {
	readfiletostring: (path: string) -> string,
	writestringtofile: (path: string, content: string) -> (),
}

local fs_utils = {} :: FileSystemInterface

local function get_parent_path(path: string): string
	-- Remove any trailing slashes
	path = path:gsub("[/\\]+$", "")

	-- Match everything up to the last slash or backslash
	local parent = path:match("^(.*)[/\\][^/\\]+$")
	return parent or ""
end

local function writestringtofile(path: string, content: string): ()
	local parent_path = get_parent_path(path)
	fs.createdirectory(parent_path, { makeparents = true })
	return fs.writestringtofile(path, content)
end

function fs_utils.readfiletostring(path: string): string
	return fs.readfiletostring(path)
end

function fs_utils.writestringtofile(path: string, content: string): ()
	return writestringtofile(path, content)
end

return fs_utils
