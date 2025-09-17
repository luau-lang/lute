local luau = require("@lute/luau")

local testSrc = [[
    --!strict
    local M = {}
    function M.getUser(id: number): {name: string, age: number}
        return {name = "Test", age = 100}
    end
    return M
]]
print(luau.getReturnType(testSrc), "\n")

local testSrc2 = [[
    --!strict
    local a = function(n: number)
        return tostring(n)
    end
    return a
]]
print(luau.getReturnType(testSrc2), "\n")

local testSrc3 = [[
    --!strict
    return {
    ["a"] = 1,
    ["b"] = 2,
    }
]]
print(luau.getReturnType(testSrc3), "\n")

local testSrc4 = [[
    --!strict
    local function a(key: string)
        return {
            [key] = 1,
        }
    end
    return a
]]
print(luau.getReturnType(testSrc4), "\n")