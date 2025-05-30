local time = require("./time")

local task = {}

function task.defer()
	error("unimplemented")
end

function task.wait(dur: (number | time.Duration)?)
	error("unimplemented")
end

return task
