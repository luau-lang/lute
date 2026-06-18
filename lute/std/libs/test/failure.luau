--!strict
-- @std/test/failure
-- utilities for working with test failures
local types = require("./types")

type Failure = types.Failure

local failures = {}

--- Returns a `Failure` describing an assertion failure at the call site, with `msg` as the failure message.
function failures.assertion(msg: string, depth: number?, negation: boolean?): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	local stackdepth = depth or 4
	local filename, linenumber = debug.info(stackdepth, "sl")
	local name = debug.info(2, "n")
	return {
		assertion = if negation then `never_{name}` else name,
		msg = msg,
		filename = filename,
		linenumber = linenumber,
		__tag = "assertion",
	}
end

--- Returns a `Failure` describing an error that occurred in the `hook` lifecycle callback.
function failures.lifecycle(hook: types.Hook, err): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	local filename, linenumber = debug.info(3, "sl")
	return { hook = hook, msg = tostring(err), filename = filename, linenumber = linenumber, __tag = "lifecycle" }
end

--- Returns a `Failure` describing an unhandled runtime error, including a stack trace.
function failures.runtimeerror(err): Failure
	-- we need to go 5 function calls up to get to the actual assertion that invoked this
	return { msg = tostring(err), stacktrace = debug.traceback(tostring(err)), __tag = "runtime_error" }
end

return table.freeze(failures)
