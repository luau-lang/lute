--!strict
-- @std/system
-- stdlib for `@lute/system`
-- Provides re-exports of `@lute/system` and boolean properties for OS detection

local system = require("@lute/system")
local path = require("@std/path")
local platform = require("@self/platform")

local systemlib = {}

function systemlib.tmpdir(): path.Path
	return path.parse(system.tmpdir())
end

-- re-exports
systemlib.os = system.os
systemlib.arch = system.arch

systemlib.threadcount = system.threadcount
systemlib.hostname = system.hostname
systemlib.totalmemory = system.totalmemory
systemlib.freememory = system.freememory
systemlib.uptime = system.uptime
systemlib.cpus = system.cpus

-- boolean properties
systemlib.win32 = platform.win32
systemlib.linux = platform.linux
systemlib.macos = platform.macos
systemlib.unix = platform.unix

return table.freeze(systemlib)
