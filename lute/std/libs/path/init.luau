local platforminfo = require("@std/system/platforminfo")

local posix = require("@self/posix")
local win32 = require("@self/win32")

local pathtypes = require("@self/types")

local pathlib = {}

type PathInterface = {
	__tostring: () -> string,
}

export type path = setmetatable<pathtypes.path, PathInterface>
export type pathlike = setmetatable<pathtypes.pathlike, PathInterface>

local onWindows = platforminfo.win32

function pathlib.basename(path: pathlike): string?
	if onWindows then
		return win32.basename(path :: win32.pathlike)
	else
		return posix.basename(path :: posix.pathlike)
	end
end

function pathlib.dirname(path: pathlike): string
	if onWindows then
		return win32.dirname(path :: win32.pathlike)
	else
		return posix.dirname(path :: posix.pathlike)
	end
end

function pathlib.extname(path: pathlike): string
	if onWindows then
		return win32.extname(path :: win32.pathlike)
	else
		return posix.extname(path :: posix.pathlike)
	end
end

function pathlib.format(path: pathlike): string
	if onWindows then
		return win32.format(path :: win32.pathlike)
	else
		return posix.format(path :: posix.pathlike)
	end
end

function pathlib.isabsolute(path: pathlike): boolean
	if onWindows then
		return win32.isabsolute(path :: win32.pathlike)
	else
		return posix.isabsolute(path :: posix.pathlike)
	end
end

function pathlib.join(...: pathlike): path
	if onWindows then
		return setmetatable(win32.join(...), pathlib)
	else
		return setmetatable(posix.join(...), pathlib)
	end
end

function pathlib.normalize(path: pathlike): path
	if onWindows then
		return setmetatable(win32.normalize(path :: win32.pathlike), pathlib)
	else
		return setmetatable(posix.normalize(path :: posix.pathlike), pathlib)
	end
end

function pathlib.parse(path: pathlike): path
	if onWindows then
		return setmetatable(win32.parse(path :: win32.pathlike), pathlib)
	else
		return setmetatable(posix.parse(path :: posix.pathlike), pathlib)
	end
end

function pathlib.resolve(...: pathlike): path
	if onWindows then
		return setmetatable(win32.resolve(...), pathlib)
	else
		return setmetatable(posix.resolve(...), pathlib)
	end
end

pathlib.win32 = win32
pathlib.posix = posix

function pathlib:__tostring(): string
	if onWindows then
		return win32.format(self :: path)
	else
		return posix.format(self :: path)
	end
end

return table.freeze(pathlib)
