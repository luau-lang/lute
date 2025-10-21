local system = require("@std/system")

local posix = require("@self/posix")
local win32 = require("@self/win32")
local types = require("@self/types")

local onWindows = system.win32

local function basename(path: types.pathlike): string?
	if onWindows then
		return win32.basename(path :: win32.pathlike)
	else
		return posix.basename(path :: posix.pathlike)
	end
end

local function dirname(path: types.pathlike): string
	if onWindows then
		return win32.dirname(path :: win32.pathlike)
	else
		return posix.dirname(path :: posix.pathlike)
	end
end

local function extname(path: types.pathlike): string
	if onWindows then
		return win32.extname(path :: win32.pathlike)
	else
		return posix.extname(path :: posix.pathlike)
	end
end

local function format(path: types.pathlike): string
	if onWindows then
		return win32.format(path :: win32.pathlike)
	else
		return posix.format(path :: posix.pathlike)
	end
end

local function isabsolute(path: types.pathlike): boolean
	if onWindows then
		return win32.isabsolute(path :: win32.pathlike)
	else
		return posix.isabsolute(path :: posix.pathlike)
	end
end

local function join(...: types.pathlike): types.path
	if onWindows then
		return win32.join(...)
	else
		return posix.join(...)
	end
end

local function normalize(path: types.pathlike): types.path
	if onWindows then
		return win32.normalize(path :: win32.pathlike)
	else
		return posix.normalize(path :: posix.pathlike)
	end
end

local function parse(path: types.pathlike): types.path
	if onWindows then
		return win32.parse(path :: win32.pathlike)
	else
		return posix.parse(path :: posix.pathlike)
	end
end

function resolve(...: types.pathlike): types.path
	if onWindows then
		return win32.resolve(...)
	else
		return posix.resolve(...)
	end
end

return table.freeze({
	win32 = win32,
	posix = posix,
	types = types,
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
