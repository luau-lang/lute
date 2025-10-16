local system = require("@lute/system")

local posix = require("@self/posix")
local win32 = require("@self/win32")

export type PathObj = posix.PosixPath | win32.WindowsPath

export type PathLike = string | PathObj

local onWindows = system.os == "windows"

function basename(path: PathLike): string?
	if onWindows then
		return win32.basename(path :: win32.WindowsPathLike)
	else
		return posix.basename(path :: posix.PosixPathLike)
	end
end

function dirname(path: PathLike): string
	if onWindows then
		return win32.dirname(path :: win32.WindowsPathLike)
	else
		return posix.dirname(path :: posix.PosixPathLike)
	end
end

function extname(path: PathLike): string
	if onWindows then
		return win32.extname(path :: win32.WindowsPathLike)
	else
		return posix.extname(path :: posix.PosixPathLike)
	end
end

function format(path: PathLike): string
	if onWindows then
		return win32.format(path :: win32.WindowsPathLike)
	else
		return posix.format(path :: posix.PosixPathLike)
	end
end

function isabsolute(path: PathLike): boolean
	if onWindows then
		return win32.isabsolute(path :: win32.WindowsPathLike)
	else
		return posix.isabsolute(path :: posix.PosixPathLike)
	end
end

function join(...: PathLike): PathObj
	if onWindows then
		return win32.join(...)
	else
		return posix.join(...)
	end
end

function normalize(path: PathLike): PathObj
	if onWindows then
		return win32.normalize(path :: win32.WindowsPathLike)
	else
		return posix.normalize(path :: posix.PosixPathLike)
	end
end

function parse(path: PathLike): PathObj
	if onWindows then
		return win32.parse(path :: win32.WindowsPathLike)
	else
		return posix.parse(path :: posix.PosixPathLike)
	end
end

function resolve(parts: { PathLike }): string
	if onWindows then
		return win32.resolve(parts :: { win32.WindowsPathLike })
	else
		return posix.resolve(parts :: { posix.PosixPathLike })
	end
end

return table.freeze({
	win32 = win32,
	posix = posix,
	basename = basename,
	dirname = dirname,
	extname = extname,
	format = format,
	isabsolute = isabsolute,
	join = join,
	normalize = normalize,
	parse = parse,
	resolve = resolve,
})
