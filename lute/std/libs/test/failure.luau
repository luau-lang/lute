--!strict
-- @std/test/failure
-- utilities for working with test failures
local types = require("./types")

type Failure = types.Failure

local failures = {}

local function isInternal(path: string?): boolean
    if not path then return false end
    return path:find("std/test") ~= nil 
        or path:find("assert.luau") ~= nil
        or path:find("failure.luau") ~= nil
end

-- Generates the debug information needed to describe assertion failure locations
function failures.assertion(msg: string): Failure
	-- get the default filename and linenumber from the caller of this function (typically 5 function calls up)
    local filename, linenumber = debug.info(4, "sl")
    local name = debug.info(2, "n")

	-- try to walk up the stack to find the user's test file (first frame that isn't part of the testing library)
	local depth = 1
    while true do
        local f, l = debug.info(depth, "sl")
        if not f then break end
        
        if not isInternal(f) then
            filename = f
            linenumber = l
            break
        end
        depth += 1
    end

    return { assertion = name, msg = msg, filename = filename, linenumber = linenumber, __tag = "assertion" }
end

-- Generates the debug information needed to describe assertion failure locations
function failures.lifecycle(hook: types.Hook, err): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	local filename, linenumber = debug.info(3, "sl")
	return { hook = hook, msg = tostring(err), filename = filename, linenumber = linenumber, __tag = "lifecycle" }
end

-- Generates the debug information needed to describe runtime error failure
function failures.runtimeerror(err): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	return { msg = tostring(err), stacktrace = debug.traceback(tostring(err)), __tag = "runtime_error" }
end

return table.freeze(failures)
