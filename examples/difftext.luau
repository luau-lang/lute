local difftext = require("@batteries/difftext")
local richterm = require("@batteries/richterm")

local src = [[
local originalVariable = 1
local same = 1

function doSomething() -- comment
    -- removed
    print(originalVariable * 2)
end

print()
]]

local destination = [[
local newVariable = 2
local same = 1

function doSomething()
    print(newVariable * 2)
end

doSomething()
]]

print(richterm.bold("Diff"))
print(difftext.prettydiff(src, destination))
print(richterm.bold("Diff (Detailed)"))
print(difftext.prettydiff(src, destination, {
	detailed = true,
}))
