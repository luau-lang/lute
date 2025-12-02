local difftext = require("@batteries/difftext")
local richterm = require("@batteries/richterm")

local src = [[
local originalVariable = 1

function doSomething()
    print(originalVariable * 2)
end
]]

local destination = [[
local newVariable = 2

function doSomething()
    print(newVariable * 2)
end
doSomething()
]]

print(richterm.bold("Diff by Char"))
print(difftext.printchardiff(src, destination))
print(richterm.bold("Diff by Line"))
print(difftext.printlinediff(src, destination))
print(richterm.bold("Diff by Line (Detailed)"))
print(difftext.printlinediff(src, destination, {
	detailed = true,
}))
