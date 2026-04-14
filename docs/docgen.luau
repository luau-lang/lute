local ps = require("@std/process")
local path = require("@std/path")
local function resolve(p : string)
    return path.resolve(ps.cwd(), p)
end

local function absolute(p : string)
    return path.format(path.join(ps.cwd(), p))
end

return {
    [resolve("../lute/std/libs")] = { alias = "@std", destination  = absolute("std")},
    [resolve("../definitions")] = { alias = "@lute", destination  = absolute("lute")},
}