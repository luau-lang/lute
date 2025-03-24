local pp = require("@batteries/pp")
local task = require("@std/task")
local time = require("@std/time")

print("Start", os.clock())
task.wait(time.duration.seconds(2))
print("End", os.clock())
