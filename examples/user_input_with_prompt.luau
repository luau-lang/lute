-- User input can be provided in multiple ways:
-- 1. lute user_input.luau
-- 2. echo "Hello!" | lute user_input_with_prompt.luau
-- 3. lute user_input_with_prompt.luau < input_text.txt

local io = require("@std/io")

-- Get user input with prompt
local name = io.input("Please enter your name: ")
print(name)
