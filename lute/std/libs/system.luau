--!strict
-- @std/system
-- stdlib for `@lute/system`
-- Provides re-exports of `@lute/system` and boolean properties for OS detection

local system = require("@lute/system")

local path = (require)("@std/path") -- trickery to avoid circular dependency
local pathTypes = require("@std/path/types")

local osName = string.lower(system.os)

local win32 = osName == "windows_nt"
local linux = osName == "linux"
local macos = osName == "darwin"
local unix = macos or linux or osName == "unix" or osName == "posix"

local function tmpdir(): pathTypes.path
	return path.parse(system.tmpdir())
end

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
