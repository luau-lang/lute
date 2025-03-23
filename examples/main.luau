local ansi = require("@batteries/ansi")
local pp = require("@batteries/pp")
local table = require("@std/table")

local merged = table.merge({ 1, 2, 3 }, { 4, 5, 6 })
print(pp(merged))
