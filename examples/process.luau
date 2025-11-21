local process = require("@std/process")
local task = require("@std/task")

local result = process.run({ "echo", "Hello, lute!" })

print(result.exitcode)
print(result.stdout)

local t1 = task.create(process.run, { "echo", "-n", "One" })
local t2 = task.create(process.run, { "echo", "-n", "Two" })
local t3 = task.create(process.run, { "echo", "-n", "Three" })

local r1, r2, r3 = task.awaitall(t1, t2, t3)

print(r1.stdout)
print(r2.stdout)
print(r3.stdout)

local r4 = process.shell("echo Hello, lute!")
print(r4.stdout)

local r5 = process.shell("echo $HOME", { env = { HOME = "/home/lute" } })
print(r5.stdout)

local r6 = process.run({ "pwd" }, { cwd = "/" })
print(r6.stdout)

local r7 = process.shell("echo $0")
print(r7.stdout)

local r8 = process.shell("echo $0", { shell = "/bin/sh" })
print(r8.stdout)

process.exit(0)
