local tableext = require("@std/tableext")
local task = require("@std/task")
local time = require("@std/time")
local vectorext = require("@std/vectorext")
local system = require("@std/system")

assert(type(tableext) == "table")
assert(type(task) == "table")
assert(type(time) == "table")
assert(type(vectorext) == "table")
assert(type(system) == "table")

return { "successfully required @std modules" }
