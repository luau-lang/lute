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

local watcher = fs.watch(tmpdir)

-- Trigger a file change event
fs.writeStringToFile(watched, "x")

-- Poll the iterator with a timeout of 2 seconds
local event
local start = os.clock()

repeat
	event = watcher:next()
	if not event then
		task.wait(0.01)
	end
until event or (os.clock() - start > 2)

if event then
	print("Event detected:", event.change and "change" or "rename")
else
	print("No event detected within the timeout period.")
end

-- Cleanup, close the watcher and remove the watched file
watcher:close()
if fs.exists(watched) then
	fs.remove(watched)
end
