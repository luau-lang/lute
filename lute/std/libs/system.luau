--!strict
-- @std/system
-- stdlib for `@lute/system`
-- Provides re-exports of `@lute/system` and boolean properties for OS detection

local system = require("@lute/system")

local osName = string.lower(system.os)

local win32 = osName == "windows"
local linux = osName == "linux"
local macos = osName == "darwin" or osName == "macos"
local unix = macos or linux or osName == "unix" or osName == "posix"

return table.freeze({
	os = system.os,
	arch = system.arch,

	-- function re-exports
	threadcount = system.threadcount,
	hostname = system.hostname,
	totalmemory = system.totalmemory,
	freememory = system.freememory,
	uptime = system.uptime,
	cpus = system.cpus,

	-- boolean properties
	win32 = win32,
	linux = linux,
	macos = macos,
	unix = unix,
})
