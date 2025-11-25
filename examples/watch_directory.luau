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

-- Give the watcher a moment to initialize
task.wait(0.1)

-- Trigger a file change event
fs.writestringtofile(watched, "x")

-- Poll the iterator with a timeout of 2 seconds
local foundChange = false
local startTime = os.clock()

local event = watcher:next()
while event and os.clock() - startTime < 2 do
	if event.change or event.rename then
		foundChange = true
	end
	event = watcher:next()
end

if foundChange then
	print("File change detected for:", watchedFileName)
else
	print("No file change detected within the timeout period.")
end

-- Cleanup, close the watcher and remove the watched file
watcher:close()
if fs.exists(watched) then
	fs.remove(watched)
end
