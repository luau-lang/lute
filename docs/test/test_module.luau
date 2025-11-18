-- This file creates a mock module called test_module with random mock functions and different types of comments to test the reference doc generator reference.luau
-- See output documentation file generated in this folder `test_module.md`

local test_module = {}

--- Property declaration test: declare process.env as a map from string to string
test_module.property = test_module.property or {} :: { [string]: string }
test_module.property["EXAMPLE_VAR"] = "value"

--- Simple function with triple dashes comment that returns hello
function test_module.triple_dash(name: string): string
	return `Hello, {name}!`
end

--- Multiple triple-dash comments (---) above function declaration
--- Should capture both of these lines

--- Even if there are blank lines between them
function test_module.multiple_triple_dashes(y: number): number
	return y + 1
end

-- this comment should not be captured because it uses double dashes

--[[
 This block comment is also not captured because there are no = signs.
]]

--- this should also not be captured because there is non function or property code
local ignore = "value"

--[=[
 Block comment with equals above function declaration
 This tests nested bracket delimiters being recognized properly.
]=]
function test_module.block_with_equals(name: string): string
	return "This is a nested bracket block comment: " .. name
end

return table.freeze(test_module)
