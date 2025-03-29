local process = require("@lute/process")
local task = require("@std/task")

local result = process.create({"echo", "Hello, lute!"})

print(result.exitCode)
print(result.stdout)

local t1 = task.create(process.create, {"echo", "-n", "One"})
local t2 = task.create(process.create, {"echo", "-n", "Two"})
local t3 = task.create(process.create, {"echo", "-n", "Three"})

local r1, r2, r3 = task.awaitall(t1, t2, t3)

print(r1.stdout)
print(r2.stdout)
print(r3.stdout)
