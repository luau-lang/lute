-- @std/fs requires @batteries/collections/deque internally
local fs = require("@std/fs")
return { exists = fs.exists }
