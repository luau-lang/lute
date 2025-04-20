type T<Value> = {
	success: true,
	value: Value,
} | {
	success: false,
	traceback: string,
	err: string,
}

local result = {}

function result.ok<Value>(value: Value): T<Value>
	return {
		success = true,
		value = value,
	}
end

function result.fail<Value>(err: string): T<Value>
	-- Ignore the current call to debug.traceback, and the call to fail.
	local traceback = debug.traceback(nil, 2)

	return {
		success = false,

		traceback = traceback,
		err = err,
	}
end

return result
