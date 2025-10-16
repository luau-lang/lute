local system = require("@lute/system")

local posix = require("@self/posix")
local win32 = require("@self/win32")

export type pathobj = posix.path | win32.path

export type pathlike = string | pathobj

local onWindows = system.os == "windows"

function basename(path: pathlike): string?
	if onWindows then
		return win32.basename(path :: win32.pathlike)
	else
		return posix.basename(path :: posix.pathlike)
	end
end

function dirname(path: pathlike): string
	if onWindows then
		return win32.dirname(path :: win32.pathlike)
	else
		return posix.dirname(path :: posix.pathlike)
	end
end

function extname(path: pathlike): string
	if onWindows then
		return win32.extname(path :: win32.pathlike)
	else
		return posix.extname(path :: posix.pathlike)
	end
end

function format(path: pathlike): string
	if onWindows then
		return win32.format(path :: win32.pathlike)
	else
		return posix.format(path :: posix.pathlike)
	end
end

function isabsolute(path: pathlike): boolean
	if onWindows then
		return win32.isabsolute(path :: win32.pathlike)
	else
		return posix.isabsolute(path :: posix.pathlike)
	end
end

function join(...: pathlike): pathobj
	if onWindows then
		return win32.join(...)
	else
		return posix.join(...)
	end
end

function normalize(path: pathlike): pathobj
	if onWindows then
		return win32.normalize(path :: win32.pathlike)
	else
		return posix.normalize(path :: posix.pathlike)
	end
end

function parse(path: pathlike): pathobj
	if onWindows then
		return win32.parse(path :: win32.pathlike)
	else
		return posix.parse(path :: posix.pathlike)
	end
end

function resolve(...: pathlike): string
	if onWindows then
		return win32.resolve(...)
	else
		return posix.resolve(...)
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
