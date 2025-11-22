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
