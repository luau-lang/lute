--!strict
-- @std/system
-- stdlib for `@lute/system`
-- Provides re-exports of `@lute/system` and boolean properties for OS detection

local system = require("@lute/system")
local path = require("@std/path")
local platforminfo = require("@self/platforminfo")

local function tmpdir(): path.path
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
	win32 = platforminfo.win32,
	linux = platforminfo.linux,
	macos = platforminfo.macos,
	unix = platforminfo.unix,
})
