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

local function errors(callback: () -> (), msg: string?): Failure?
	local success = pcall(callback)
	-- if the callback failed, then this assert passes
	if not success then
		return nil
	end

	return assertion(msg or `{callback} did not throw error.`)
end

-- FIXME(Luau): We would like this to be two read-only indexers, but the
-- best option we have otherwise is two error suppressing indexers.
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

local function erroreq<A...>(func: (A...) -> ...unknown, expectedErrorMessage: string, ...: A...): Failure?
	local success, err = pcall(func, ...)
	if success then
		return assertion("Function did not error as expected.")
	end

	local actualErrorMessage = tostring(err)
	-- pcall appends filename and line number of the error, so we check suffix only
	if not stringext.hassuffix(actualErrorMessage, expectedErrorMessage) then
		return assertion(`Expected suffix of error message "{expectedErrorMessage}", but got "{actualErrorMessage}"`)
	end

	return nil
end

local function eq(lhs: unknown, rhs: unknown, msg: string?): Failure?
	-- Simple equality check for non-tables
	if lhs == rhs then
		return nil
	end

	-- Handle type mismatch
	if typeof(lhs) ~= typeof(rhs) then
		return assertion(msg or `lhs is of type {typeof(lhs)}, but rhs is of type {typeof(rhs)}`)
	end

	-- Check for buffer equality
	if typeof(lhs) == "buffer" then
		return buffereq(lhs :: buffer, rhs :: buffer)
	end

	-- Check for table equality
	if typeof(lhs) == "table" then
		return tableeq(lhs :: { [any]: any }, rhs :: { [any]: any })
	end

	return assertion(msg or `{lhs} ~= {rhs}`)
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
	errors = reqassert(errors),
	erroreq = reqassert(erroreq),
	strcontains = reqassert(strcontains),
	strnotcontains = reqassert(strnotcontains),
	that = reqassert(that),
}) :: Asserts
