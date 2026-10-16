local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local dir = "tests/std/snapshots/io/input"

local util = {}

-- Pipes `{testName}.in` into `{child}` as stdin so io.input() reads it like typed
-- input. Runs from `dir`, so the piped names need no path separators.
function util.pipeInput(testName: string, child: string)
	local lute = path.format(process.execPath())
	local cat = if system.win32 then "type" else "cat"
	print(process.system(`{cat} {testName}.in | {lute} {child}`, { cwd = dir }).stdout)
end

return util
