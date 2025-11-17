-- This file creates a mock module called test_module with random mock functions and different types of comments to test the reference doc generator reference.luau
-- See output documentation file generated in this folder `test_module.md`

local test_module = {}

-- Property declaration test: declare process.env as a map from string to string
test_module.property = test_module.property or {} :: { [string]: string }
test_module.property["EXAMPLE_VAR"] = "value"

-- Simple add function with two dashes comment that returns the sum of two numbers
function test_module.single_line(a: number, b: number): number
	return a + b
end

--- Simple function with triple dashes comment that returns hello
function test_module.triple_dash(name: string): string
	return "Hello, " .. name .. "!"
end

-- Single line comment (--) directly above function declaration
-- Should capture both of these single-line comments as a comment for the multiple_single_lines function
function test_module.multiple_single_lines(x: number): number
	return x * 2
end

--- Multiple triple-dash comments (---) above function declaration
--- Should capture both of these lines
function test_module.multiple_triple_dashes(y: number): number
	return y + 1
end

--[[
 Block comment above function declaration
 It can span multiple lines and include more detail.
]]
function test_module.block(a: string, b: string): string
	return a .. b
end

--[=[
 Block comment with equals above function declaration
 This tests nested bracket delimiters being recognized properly.
]=]
function test_module.block_with_equals(name: string): string
	return "This is a nested bracket block comment: " .. name
end

return table.freeze(test_module)
