-- Snapshot for issue #1172: io.input() returns the line without its trailing
-- terminator. The snapshot harness provides no stdin, so each value is piped into a
-- child lute process; echo appends the platform terminator (CRLF on Windows, LF on
-- Unix). The length is printed alongside the value so a surviving terminator stays
-- visible even after the harness normalizes line endings.
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local lutePath = path.format(process.execPath())
local childPath = path.format(path.join(system.tmpdir(), "io_input_snap_child.luau"))
fs.writeStringToFile(
	childPath,
	[[
	local io = require("@std/io")
	local line = io.input()
	io.write(`<{line}> len={#line}`)
]]
)

-- Paths are unquoted (no spaces) since libuv mangles embedded quotes for cmd.exe.
for _, value in { "x.txt", "some/dir/file.txt", "a b" } do
	local r = process.system(`echo {value}| {lutePath} {childPath}`)
	print(`{value} -> exit={r.exitcode} {r.stdout}`)
end

fs.remove(childPath)
