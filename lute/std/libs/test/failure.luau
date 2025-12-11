--!strict
-- @std/test/failure
-- utilities for working with test failures
local types = require("./types")

type failure = types.failure

local failures = {}
-- Generates the debug information needed to describe assertion failure locations
function failures.assertion(msg: string): failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	local filename, linenumber = debug.info(4, "sl")
	local name = debug.info(2, "n")
	return { assertion = name, msg = msg, filename = filename, linenumber = linenumber, __tag = "assertion" }
end

-- Generates the debug information needed to describe assertion failure locations
function failures.lifecycle(hook: hook, err): failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	local filename, linenumber = debug.info(3, "sl")
	return { hook = hook, msg = tostring(err), filename = filename, linenumber = linenumber, __tag = "lifecycle" }
end

-- Generates the debug information needed to describe runtime error failure
function failures.runtimeerror(err): failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	return { msg = tostring(err), stacktrace = debug.traceback(tostring(err)), __tag = "runtime_error" }
end

return table.freeze(failures)
