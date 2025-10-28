local luau = require("@std/luau")

local pretty = require("@batteries/pp")

local foo = luau.parseexpr("5")
print(pretty(foo))
