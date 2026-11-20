--!strict
-- a and b both alias @c, but to different revisions of the same package; each
-- must load its own revision in a single run.
local a = require("@a")
local b = require("@b")

assert(a == "a:c1", "a got " .. a)
assert(b == "b:c2", "b got " .. b)
