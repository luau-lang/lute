local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

local filePath = path.join(process.cwd(), "examples", "module_return_type", "mainmodule.luau")
local returnType = luau.typeofModule(filePath)

if not returnType then
	error("Failed to get module return type")
end

if not returnType.head then
	error("Return type head is nil")
end

for _, retType in ipairs(returnType.head) do
	if retType.tag ~= "table" then
		error("Expected return type to be a table")
	end

	if not retType.properties then
		error("Return type table has no properties")
	end

	for name, prop in pairs(retType.properties) do
		if prop.read then
			print(name .. ": " .. prop.read.tag)
		elseif prop.write then
			print(name .. ": " .. prop.write.tag)
		else
			print(name .. ": (no read or write type)")
		end
	end
end

-- Output:
-- func1: function
-- strings: table
-- _metadata: table

-- Actual Module return type
-- {
--     _metadata: {
--         id: string,
--         key: number
--     },
--     func1: (a: number) -> (s: string) -> boolean,
--     strings: {
--         [string]: string
--     }
-- }
