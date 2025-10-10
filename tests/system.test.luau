local stdSystem = require("@std/system")
local system = require("@lute/system")

local function test_systemEnvironmentBooleanProperties()
	local osName = string.lower(system.os)

	local win32 = osName == "windows"
	local linux = osName == "linux"
	local macos = osName == "darwin" or osName == "macos"
	local unix = macos or linux or osName == "unix" or osName == "posix"

	assert(stdSystem.win32 == win32)
	assert(stdSystem.linux == linux)
	assert(stdSystem.macos == macos)
	assert(stdSystem.unix == unix)
end

test_systemEnvironmentBooleanProperties()
