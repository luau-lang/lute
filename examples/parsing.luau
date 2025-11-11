local parser = require("@std/syntax/parser")

local pretty = require("@batteries/pp")

local foo = parser.parseexpr("5")
print(pretty(foo))
