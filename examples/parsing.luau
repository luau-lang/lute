local syntax = require("@std/syntax")

local pretty = require("@batteries/pp")

local foo = syntax.parseExpr("5")
print(pretty(foo))
