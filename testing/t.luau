local types = require("@root/types")
local tricky = require("@std/table")

local testFilter: { [string]: number } = {
    ["a"] = 1,
    ["b"] = 2,
}

local a = {}
type tb = tricky.dictionary<number>

function a._a(a: number)
    return function(s: string): types.test
       return types(s, a)
    end
end

a._b = tricky.map(testFilter, function(value)
    return tostring(value)
end)

a._metadata = {
    key = -1,
    id = 'nice'
}

return a