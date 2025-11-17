local types = require("../types")
type Case = types.Case

return {
	{
		initial = [[
    local oldLibrary = require(packagesRoot.old)

    local function myDependentFunction(input: { string }): boolean
        for _, s in input do
            if oldLibrary.oldFunction(input) then
                return true
            end
        end
        return false
    end

    local function myIndexUsingDependentFunction(input: string): boolean
        return oldLibrary.anotherFunction(input)
    end
    ]],
		expected = [[
    local newLibrary = require(packagesRoot.new)

    local function myDependentFunction(input: { string }): boolean
        for _, s in input do
            if newLibrary.newFunction(input) then
                return true
            end
        end
        return false
    end

    local function myIndexUsingDependentFunction(input: string): boolean
        return newLibrary.anotherNewFunction(input)
    end
    ]],
	},
	{
		initial = [[
    local oldLibraryDiffAlias = require(root.nested.packages.old)

    local myEl = oldLibraryDiffAlias.oldFunction("lol")

    return oldLibraryDiffAlias.anotherFunction(myEl)
    ]],
            expected = [[
    local newLibrary = require(root.nested.packages.new)

    local myEl = newLibrary.newFunction("lol")

    return newLibrary.anotherNewFunction(myEl)
    ]],
	},
} :: { Case }
