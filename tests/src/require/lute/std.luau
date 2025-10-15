local table = require("@std/table")
local task = require("@std/task")
local time = require("@std/time")
local vector = require("@std/vector")
local system = require("@std/system")

assert(type(table) == "table")
assert(type(task) == "table")
assert(type(time) == "table")
assert(type(vector) == "table")
assert(type(system) == "table")

return { "successfully required @std modules" }
