--!strict
-- @std/test/assert
-- Standard assertion library for Luau

local failure = require("./failure")
local stringext = require("@std/stringext")
local types = require("./types")

-- types
type Failure = types.Failure
type Asserts = types.Asserts

-- more utils
local assertion = failure.assertion

-- Helper to format values for error messages
local function formatValue(val: any): string
	if type(val) == "nil" then
		return "nil"
	elseif type(val) == "string" then
		return `"{val}"`
	elseif type(val) == "table" then
		return "table"
	else
		return tostring(val)
	end
end

-- Structural equality for two tables
local function tablesEqual(t1: unknown, t2: unknown, path: string): (boolean, string?)
	if typeof(t1) ~= "table" or typeof(t2) ~= "table" then
		if t1 ~= t2 then
			return false, `lhs{path} = {formatValue(t1)} but rhs{path} = {formatValue(t2)}`
		end
		return true, nil
	end

	-- Check all keys in t1
	for k, v1 in t1 do
		local v2 = (t2 :: any)[k]
		local newPath = if path == "" then `[{k}]` else `{path}[{k}]`

		-- Check if key exists in t2
		if v2 == nil then
			return false, `lhs{newPath} = {formatValue(v1)} but rhs{newPath} does not exist`
		end

		local equal, msg = tablesEqual(v1, v2, newPath)
		if not equal then
			return false, msg
		end
	end

	-- Check for keys in t2 that aren't in t1
	for k, v in t2 do
		local v1 = (t1 :: any)[k]
		if v1 == nil then
			local newPath = if path == "" then `[{k}]` else `{path}[{k}]`
			return false, `rhs{newPath} = {formatValue(v)} but lhs{newPath} does not exist`
		end
	end

	return true, nil
end

local function eq<T>(lhs: T, rhs: T, msg: string?): Failure?
	if lhs == rhs then
		return nil
	end

	return assertion(msg or `{lhs} ~= {rhs}`)
end

local function neq<T>(lhs: T, rhs: T, msg: string?): Failure?
	if lhs ~= rhs then
		return nil
	end

	return assertion(msg or `{lhs} == {rhs}`)
end

local function that(value: unknown, msg: string?): Failure?
	if value then
		return nil
	end

	return assertion(msg or `Expected a truthy value, but got {formatValue(value)}`)
end

local function throws<T...>(func: (T...) -> ...unknown, ...: T...): Failure?
	local success = pcall(func, ...)
	-- if the callback failed, then this assert passes
	if not success then
		return nil
	end

	return assertion(`{func} did not throw error.`)
end

-- Table equality assertionsion with deep comparison
local function tableeq(lhs: { [any]: any }, rhs: { [any]: any }): Failure?
	local equal, msg = tablesEqual(lhs, rhs, "")
	if equal then
		return nil
	end
	return assertion(msg or "tables are not equal")
end

local function buffereq(lhs: buffer, rhs: buffer): Failure?
	if typeof(lhs) ~= "buffer" then
		return assertion(`lhs is of type {typeof(lhs)}, not buffer`)
	end

	if typeof(rhs) ~= "buffer" then
		return assertion(`rhs is of type {typeof(rhs)}, not buffer`)
	end

	if buffer.len(lhs) ~= buffer.len(rhs) then
		return assertion("buffers are of unequal length")
	end

	local len = buffer.len(lhs)
	for offset = 0, len - 1 do
		local left = buffer.readu8(lhs, offset)
		local right = buffer.readu8(rhs, offset)

		if left ~= right then
			return assertion(string.format("lhs[%d] = %02x, but rhs[%d] = %02x", offset, left, offset, right))
		end
	end
	return nil
end

local function throwsWith<T...>(with: any, func: (T...) -> ...unknown, ...: T...): Failure?
	local success, err = pcall(func, ...)
	if success then
		return assertion(`Expected {func} to throw/raise error.`)
	end

	local actualErrorMessage = tostring(err)

	if typeof(with) == "string" then
		-- pcall appends filename and line number of the error, so we check suffix only
		if not stringext.hassuffix(actualErrorMessage, with) then
			return assertion(`Expected suffix of error message "{with}", but got "{actualErrorMessage}"`)
		end
	else
		return eq(err, with, `Expected error "{with}", but got "{formatValue(err)}"`)
	end

	return nil
end

local function strcontains(haystack: string, needle: string, instances: number?, msg: string?): Failure?
	if instances == nil then
		if haystack:find(needle, 1, true) == nil then
			return assertion(if msg then msg else `Expected "{haystack}" to contain "{needle}".`)
		end

		return nil
	end

	instances = instances or 1

	if instances <= 0 then
		return assertion("instances must be greater than 0")
	end

	if #haystack:split(needle) ~= instances + 1 then
		return assertion(if msg then msg else `Expected "{haystack}" to contain "{needle}" {instances} times.`)
	end

	return nil
end

local function strnotcontains(haystack: string, needle: string, msg: string?): Failure?
	if haystack:find(needle, 1, true) ~= nil then
		return assertion(if msg then msg else `Expected "{haystack}" to not contain "{needle}".`)
	end

	return nil
end

-- utility for taking an assertion and wrapping it as a check that must complete successfully or will return control flow to the error handler
local function reqassert<T...>(req: (T...) -> Failure?): (T...) -> Failure?
	return function(...): Failure?
		local result: Failure? = req(...)
		if result ~= nil then
			error(result)
		end

		return nil
	end
end

return table.freeze({
	eq = reqassert(eq),
	neq = reqassert(neq),
	throws = reqassert(throws),
	tableeq = reqassert(tableeq),
	buffereq = reqassert(buffereq),
	throwsWith = reqassert(throwsWith),
	strcontains = reqassert(strcontains),
	strnotcontains = reqassert(strnotcontains),
	that = reqassert(that),
}) :: Asserts
