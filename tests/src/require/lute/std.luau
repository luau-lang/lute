local tableext = require("@std/tableext")
local task = require("@std/task")
local time = require("@std/time")
local system = require("@std/system")

assert(type(tableext) == "table")
assert(type(task) == "table")
assert(type(time) == "table")
assert(type(system) == "table")

return { "successfully required @std modules" }
