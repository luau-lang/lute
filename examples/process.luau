local process = require("@std/process")

process.system("echo hello", {})

local result = process.run({ "echo", "Hello, lute!" })

print(result.exitcode)
print(result.stdout)

local r1 = process.run({ "echo", "-n", "One" })
local r2 = process.run({ "echo", "-n", "Two" })
local r3 = process.run({ "echo", "-n", "Three" })

print(r1.stdout)
print(r2.stdout)
print(r3.stdout)

local r4 = process.system("echo Hello, lute!")
print(r4.stdout)

local r5 = process.system("echo $HOME", { env = { HOME = "/home/lute" } })
print(r5.stdout)

local r6 = process.run({ "pwd" }, { cwd = "/" })
print(r6.stdout)

local r7 = process.system("echo $0")
print(r7.stdout)

local r8 = process.system("echo $0", { system = "/bin/sh" })
print(r8.stdout)

process.exit(0)
