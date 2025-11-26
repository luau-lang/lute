local diffText = require("@batteries/diffText")
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
]]

print(richterm.bold("Diff by Line"))
diffText.printdiffbyline(src, destination)
print(richterm.bold("Diff by Char"))
diffText.printdiffbychar(src, destination)
