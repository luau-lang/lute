local task = require("@lute/task")
local total_sum = 0

task.spawn(function()
	for i = 1, 5 do
		task.wait(0)
		total_sum += 1
	end
end)

task.spawn(function()
	for i = 1, 5 do
		task.wait(0)
		total_sum += 1
	end
end)

while total_sum ~= 10 do
	task.wait(0.01)
end
-- just for checking after we joined both threads
total_sum += 1
