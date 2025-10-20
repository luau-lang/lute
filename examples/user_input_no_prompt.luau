-- User input can be provided in multiple ways:
-- 1. lute user_input.luau
-- 2. echo "Hello!" | lute user_input_no_prompt.luau
-- 3. lute user_input_no_prompt.luau < input_text.txt

local io = require("@std/io")

-- Get user input
local input = io.input()
print(input)
