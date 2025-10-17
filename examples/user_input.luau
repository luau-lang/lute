local io = require("@std/io")

-- Get user input
local input = io.input()
print(input)

-- Get user input with a prompt
local inputWithPrompt = io.input("Please enter something: ")
print(inputWithPrompt)