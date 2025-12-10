local platform = require("@std/system/platform")

local posix = require("@self/posix")
local win32 = require("@self/win32")

local pathtypes = require("@self/types")

local pathlib = {}

export type path = pathtypes.path
export type pathlike = pathtypes.pathlike

local onWindows = platform.win32

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
		return win32.join(...)
	else
		return posix.join(...)
	end
end

function pathlib.normalize(path: pathlike): path
	if onWindows then
		return win32.normalize(path :: win32.pathlike)
	else
		return posix.normalize(path :: posix.pathlike)
	end
end

function pathlib.parse(path: pathlike): path
	if onWindows then
		return win32.parse(path :: win32.pathlike)
	else
		return posix.parse(path :: posix.pathlike)
	end
end

function pathlib.relative(from: pathlike, to: pathlike): path
	if onWindows then
		return win32.relative(from :: win32.pathlike, to :: win32.pathlike)
	else
		return posix.relative(from :: posix.pathlike, to :: posix.pathlike)
	end
end

function pathlib.resolve(...: pathlike): path
	if onWindows then
		return win32.resolve(...)
	else
		return posix.resolve(...)
	end
end

pathlib.win32 = win32
pathlib.posix = posix

return table.freeze(pathlib)
