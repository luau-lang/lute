local syntax = require("@std/syntax")

local pretty = require("@batteries/pp")

local foo = syntax.parseexpr("5")
print(pretty(foo))
