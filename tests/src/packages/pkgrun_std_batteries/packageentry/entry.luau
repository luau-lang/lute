--!strict
-- @std/fs requires @batteries/collections/deque internally
local fs = require("@std/fs")
assert(type(fs) == "table")
assert(type(fs.exists) == "function")

local dep = require("@dep")
assert(dep.exists == fs.exists)
