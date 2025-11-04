--!strict
-- @std/system
-- stdlib for `@lute/system`
-- Provides re-exports of `@lute/system` and boolean properties for OS detection

local system = require("@lute/system")
local path = require("@std/path")
local platforminfo = require("@self/platforminfo")

local systemlib = {}

function systemlib.tmpdir(): path.path
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
systemlib.win32 = platforminfo.win32
systemlib.linux = platforminfo.linux
systemlib.macos = platforminfo.macos
systemlib.unix = platforminfo.unix

return table.freeze(systemlib)
