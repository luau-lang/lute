local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local dir = "tests/std/snapshots/ioinput"

local util = {}

-- Pipes `{testName}.in` into a child running io.input() and prints the result in <>,
-- so any trailing terminator that should have been stripped is visible in the snapshot.
function util.printInput(testName: string)
	local lute = path.format(process.execPath())
	local cat = if system.win32 then "type" else "cat"
	local inFile = `{dir}/{testName}.in`
	local child = `{dir}/readinput.luau`
	if system.win32 then
		inFile = (string.gsub(inFile, "/", "\\"))
		child = (string.gsub(child, "/", "\\"))
	end
	print(process.system(`{cat} {inFile}| {lute} {child}`).stdout)
end

return util
