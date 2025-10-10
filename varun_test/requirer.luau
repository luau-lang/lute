local args = { ... }
assert(#args == 2, "Expected one argument: path to Luau script to require")

local luau = require("@lute/luau")
local result = luau.requirefromcwd(args[2])
print(result)
