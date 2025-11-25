local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local task = require("@lute/task")

-- Setup, get a temporary directory to watch
local tmpdir = system.tmpdir()

local watchedFileName = "watched.txt"
local watched = path.join(tmpdir, watchedFileName)
if fs.exists(watched) then
	fs.remove(watched)
end

local it = fs.watch(tmpdir)

-- Give the watcher a moment to initialize
task.wait(0.1)

-- Trigger a file change event
fs.writestringtofile(watched, "x")

-- Poll the iterator with a timeout of 2 seconds
local triggered = false
local start = os.time()

while not triggered and (os.time() - start) < 2 do
	local ev = it()

	if ev then
		if tostring(ev.filename) == watchedFileName then
			triggered = true
		end
	end

	task.wait(0.05) -- Poll every 50ms
end

if triggered then
	print("File change detected for:", watchedFileName)
else
	print("No file change detected within the timeout period.")
end

-- Cleanup, close the watcher and remove the watched file
it:close()
if fs.exists(watched) then
	fs.remove(watched)
end
