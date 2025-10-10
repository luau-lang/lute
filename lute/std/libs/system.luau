--!strict

local system = require("@lute/system")

local osName = string.lower(system.os)

local win32 = osName == "windows"
local linux = osName == "linux"
local macos = osName == "darwin" or osName == "macos"
local unix = macos or linux or osName == "unix" or osName == "posix"

return table.freeze({
	os = system.os,

	win32 = win32,
	linux = linux,
	macos = macos,
	unix = unix,
})
