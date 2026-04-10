--!strict
-- @std/system
-- stdlib for `@lute/system`
-- Provides re-exports of `@lute/system` and boolean properties for OS detection

local system = require("@lute/system")
local path = require("@std/path")
local platform = require("@self/platform")

local systemlib = {}

--- Returns the path of the system's temporary directory.
function systemlib.tmpdir(): path.Path
	return path.parse(system.tmpdir())
end

-- re-exports
systemlib.os = system.os
systemlib.arch = system.arch

systemlib.threadCount = system.threadCount
systemlib.hostName = system.hostName
systemlib.totalMemory = system.totalMemory
systemlib.freeMemory = system.freeMemory
systemlib.uptime = system.uptime
systemlib.cpus = system.cpus

-- boolean properties
systemlib.win32 = platform.win32
systemlib.linux = platform.linux
systemlib.macos = platform.macos
systemlib.unix = platform.unix

return table.freeze(systemlib)
