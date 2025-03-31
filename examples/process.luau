local process = require("@lute/process")
local task = require("@std/task")

local result = process.create({ "echo", "Hello, lute!" })

print(result.exitcode)
print(result.stdout)

local t1 = task.create(process.create, { "echo", "-n", "One" })
local t2 = task.create(process.create, { "echo", "-n", "Two" })
local t3 = task.create(process.create, { "echo", "-n", "Three" })

local r1, r2, r3 = task.awaitall(t1, t2, t3)

print(r1.stdout)
print(r2.stdout)
print(r3.stdout)

local r4 = process.create("echo Hello, lute!", { shell = true })
print(r4.stdout)

local r5 = process.create({ "echo", "$HOME" }, { env = { HOME = "/home/lute" }, shell = true })
print(r5.stdout)

local r6 = process.create({ "pwd" }, { cwd = "/" })
print(r6.stdout)

local r7 = process.create("echo $0", { shell = true })
print(r7.stdout)

local r8 = process.create("echo $0", { shell = "/bin/sh" })
print(r8.stdout)
