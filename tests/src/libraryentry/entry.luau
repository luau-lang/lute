--!strict
local result = require("@dep") :: { string }
assert(type(result) == "table")
assert(#result == 2)

assert(result[1] == "internal")
assert(result[2] == "external")
