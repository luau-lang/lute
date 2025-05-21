local task = require("@lute/task")
local time = require("@lute/time")

print(task.wait(1))
print(task.wait(time.duration.seconds(1)))
print(task.wait())

-- while true do
-- 	local start = time.now()
-- 	local delta = task.wait(1)
-- 	local stop = time.now()

-- 	print(stop - start)

-- 	print(delta)
-- end
