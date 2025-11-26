local diffText = require("@batteries/diffText")

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

diffText.printdiffbyline(src, destination)
