local vm = require("@lute/vm")
local task = require("@std/task")

local threadCount = 8

for i = 1, threadCount do
	task.create(vm.create("./parallel_serve_helper").serve)
end

print(`Created {threadCount} server threads`)
