local platform = require("@std/system/platform")

local posix = require("@self/posix")
local win32 = require("@self/win32")

local pathtypes = require("@self/types")

local pathlib = {}

--- A structured, platform-aware file system path.
export type Path = pathtypes.Path
--- Anything that can be used as a path: a string, a `Path`, or raw path data.
export type Pathlike = pathtypes.Pathlike

local onWindows = platform.win32

--- Returns the last component of `path` (the filename or directory name), or `nil` if the path has no components.
function pathlib.basename(path: Pathlike): string?
	if onWindows then
		return win32.basename(path :: win32.Pathlike)
	else
		return posix.basename(path :: posix.Pathlike)
	end
end

--- Returns the directory portion of `path` as a string (everything except the last component).
function pathlib.dirname(path: Pathlike): string
	if onWindows then
		return win32.dirname(path :: win32.Pathlike)
	else
		return posix.dirname(path :: posix.Pathlike)
	end
end

--- Returns the file extension of `path` (including the leading dot), or `""` if there is none.
function pathlib.extname(path: Pathlike): string
	if onWindows then
		return win32.extname(path :: win32.Pathlike)
	else
		return posix.extname(path :: posix.Pathlike)
	end
end

--- Converts `path` to its string representation using the platform's separator.
function pathlib.format(path: Pathlike): string
	if onWindows then
		return win32.format(path :: win32.Pathlike)
	else
		return posix.format(path :: posix.Pathlike)
	end
end

--- Returns `true` if `path` is absolute.
function pathlib.isAbsolute(path: Pathlike): boolean
	if onWindows then
		return win32.isAbsolute(path :: win32.Pathlike)
	else
		return posix.isAbsolute(path :: posix.Pathlike)
	end
end

--- Joins one or more path segments together into a single `Path`. Each segment after the first must be relative.
function pathlib.join(...: Pathlike): Path
	if onWindows then
		return win32.join(...)
	else
		return posix.join(...)
	end
end

--- Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.
function pathlib.normalize(path: Pathlike): Path
	if onWindows then
		return win32.normalize(path :: win32.Pathlike)
	else
		return posix.normalize(path :: posix.Pathlike)
	end
end

--- Parses `path` into a structured `Path` value.
function pathlib.parse(path: Pathlike): Path
	if onWindows then
		return win32.parse(path :: win32.Pathlike)
	else
		return posix.parse(path :: posix.Pathlike)
	end
end

--- Returns the relative path from `from` to `to`. Both paths must be of the same kind (both absolute or both relative).
function pathlib.relative(from: Pathlike, to: Pathlike): Path
	if onWindows then
		return win32.relative(from :: win32.Pathlike, to :: win32.Pathlike)
	else
		return posix.relative(from :: posix.Pathlike, to :: posix.Pathlike)
	end
end

--- Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.
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
