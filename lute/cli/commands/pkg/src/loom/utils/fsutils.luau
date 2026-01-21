local fs = require("@std/fs")

export type FileSystemInterface = {
	readfiletostring: (path: string) -> string,
	writestringtofile: (path: string, content: string) -> (),
}

local fsUtils = {} :: FileSystemInterface

local function getParentPath(path: string): string
	-- Remove any trailing slashes
	path = path:gsub("[/\\]+$", "")

	-- Match everything up to the last slash or backslash
	local parent = path:match("^(.*)[/\\][^/\\]+$")
	return parent or ""
end

local function writestringtofile(path: string, content: string): ()
	local parentPath = getParentPath(path)
	fs.createdirectory(parentPath, { makeparents = true })
	return fs.writestringtofile(path, content)
end

function fsUtils.readfiletostring(path: string): string
	return fs.readfiletostring(path)
end

function fsUtils.writestringtofile(path: string, content: string): ()
	return writestringtofile(path, content)
end

return fsUtils
