local platform = require("@std/system/platform")

local posix = require("@self/posix")
local win32 = require("@self/win32")

local pathtypes = require("@self/types")

local pathlib = {}

export type Path = pathtypes.Path
export type Pathlike = pathtypes.Pathlike

local onWindows = platform.win32

function pathlib.basename(path: Pathlike): string?
	if onWindows then
		return win32.basename(path :: win32.Pathlike)
	else
		return posix.basename(path :: posix.Pathlike)
	end
end

function pathlib.dirname(path: Pathlike): string
	if onWindows then
		return win32.dirname(path :: win32.Pathlike)
	else
		return posix.dirname(path :: posix.Pathlike)
	end
end

function pathlib.extname(path: Pathlike): string
	if onWindows then
		return win32.extname(path :: win32.Pathlike)
	else
		return posix.extname(path :: posix.Pathlike)
	end
end

function pathlib.format(path: Pathlike): string
	if onWindows then
		return win32.format(path :: win32.Pathlike)
	else
		return posix.format(path :: posix.Pathlike)
	end
end

function pathlib.isAbsolute(path: Pathlike): boolean
	if onWindows then
		return win32.isAbsolute(path :: win32.Pathlike)
	else
		return posix.isAbsolute(path :: posix.Pathlike)
	end
end

function pathlib.join(...: Pathlike): Path
	if onWindows then
		return win32.join(...)
	else
		return posix.join(...)
	end
end

function pathlib.normalize(path: Pathlike): Path
	if onWindows then
		return win32.normalize(path :: win32.Pathlike)
	else
		return posix.normalize(path :: posix.Pathlike)
	end
end

function pathlib.parse(path: Pathlike): Path
	if onWindows then
		return win32.parse(path :: win32.Pathlike)
	else
		return posix.parse(path :: posix.Pathlike)
	end
end

function pathlib.relative(from: Pathlike, to: Pathlike): Path
	if onWindows then
		return win32.relative(from :: win32.Pathlike, to :: win32.Pathlike)
	else
		return posix.relative(from :: posix.Pathlike, to :: posix.Pathlike)
	end
end

function pathlib.resolve(...: Pathlike): Path
	if onWindows then
		return win32.resolve(...)
	else
		return posix.resolve(...)
	end
end

pathlib.win32 = win32
pathlib.posix = posix

return table.freeze(pathlib)
