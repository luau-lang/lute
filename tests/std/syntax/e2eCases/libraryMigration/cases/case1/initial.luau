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
