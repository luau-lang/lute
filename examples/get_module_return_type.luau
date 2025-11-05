local luau = require("@std/luau")

local moduleTypeString = luau.typeofmodule("./lute/std/libs/task.luau")

print("Module return type\n", moduleTypeString)

-- Output:
-- Module return type
--         {
--     await: (t: {
--         co: thread,
--         result: any,
--         success: boolean?
--     }) -> any,
--     awaitall: (...{
--         co: thread,
--         result: any,
--         success: boolean?
--     }) -> (...any),
--     create: <a..., b...>(f: (a...) -> (b...), ...any) -> {
--         co: thread,
--         result: any,
--         success: boolean?
--     }
-- }
