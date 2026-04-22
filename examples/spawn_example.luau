local vm = require("@lute/vm")

local task = require("@std/task")

print("start")

local vm1 = vm.create("./fib")
local vm2 = vm.create("./fib")
local vm3 = vm.create("./fib")

print("fib(15):", vm1.fib(15))
print("fib(20):", vm2.fib(20))
print("done inline")

do
	local start = os.clock()

	print("fib(10):", vm1.fib(10))
	print("fib(20):", vm1.fib(20))
	print("fib(33):", vm1.fib(33))

	print("multiple direct fib in", os.clock() - start)
end

do
	local start = os.clock()

	print("fib(33):", vm1.fib(33))

	print("single task fib in", os.clock() - start)
end

do
	local start = os.clock()

	print("fib(33):", vm1.fibTable({ n = 33 }))

	print("single task fibTable in", os.clock() - start)
end

do
	local start = os.clock()

	local results = {}
	local done = 0

	task.spawn(function()
		results[1] = vm1.fib(33)
		done += 1
	end)
	task.spawn(function()
		results[2] = vm1.fib(33)
		done += 1
	end)
	task.spawn(function()
		results[3] = vm1.fib(33)
		done += 1
	end)

	while done < 3 do
		task.wait()
	end

	print("fib(33):", results[1], results[2], results[3])

	print("3 serial fibs in", os.clock() - start)
end

do
	local start = os.clock()

	local results = {}
	local done = 0

	task.spawn(function()
		results[1] = vm1.fib(33)
		done += 1
	end)
	task.spawn(function()
		results[2] = vm2.fib(33)
		done += 1
	end)
	task.spawn(function()
		results[3] = vm3.fib(33)
		done += 1
	end)

	while done < 3 do
		task.wait()
	end

	print("fib(33):", results[1], results[2], results[3])

	print("3 parallel fibs in", os.clock() - start)
end

print("completed")
