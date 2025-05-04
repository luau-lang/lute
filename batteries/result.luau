type T<Value> = | { success: true, value: Value } | { success: false, traceback: string, err: string }

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

function result.pcall<R, T...>(f: (T...) -> R, ...: T...): T<R>
	local success, value = pcall(f, ...)

	if success then
		return result.ok(value)
	else
		local err = value :: any

		return result.fail(err)
	end
end

return result
