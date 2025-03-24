local pp = require("@batteries/pp")
local task = require("@std/task")
local random = require("@std/random")

local robj = random.new(os.time())

print(robj:NextNumber())
print(robj:NextNumber())
print(robj:NextInteger(1, 10))
