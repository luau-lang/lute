--!strict
--!native
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

local function that(negate: boolean, value: unknown, msg: string?): Failure?
	if negate then
		if not value then
			return nil
		end
		return assertion(msg or `Expected a falsy value, but got {formatValue(value)}`, nil, true)
	end

	if value then
		return nil
	end
	return assertion(msg or `Expected a truthy value, but got {formatValue(value)}`)
end

local function throws<T...>(negate: boolean, func: (T...) -> ...unknown, ...: T...): Failure?
	local success = pcall(func, ...)

	if negate then
		if success then
			return nil
		end
		return assertion(`{func} threw an unexpected error.`, nil, true)
	end

	if not success then
		return nil
	end
	return assertion(`{func} did not throw error.`)
end

-- FIXME(Luau): We would like this to be two read-only indexers, but the
-- best option we have otherwise is two error suppressing indexers.
-- Table equality assertionsion with deep comparison
local function tableeq(negate: boolean, lhs: { [any]: any }, rhs: { [any]: any }, depth: number?): Failure?
	local stackdepth = depth or 4
	local equal, msg = tablesEqual(lhs, rhs, "")

	if negate then
		if not equal then
			return nil
		end
		return assertion("expected tables to not be equal", stackdepth, true)
	end

	if equal then
		return nil
	end
	return assertion(msg or "tables are not equal", stackdepth)
end

local function buffereq(negate: boolean, lhs: buffer, rhs: buffer, depth: number?): Failure?
	local stackdepth = depth or 4

	if typeof(lhs) ~= "buffer" then
		return assertion(`lhs is of type {typeof(lhs)}, not buffer`, stackdepth)
	end

	if typeof(rhs) ~= "buffer" then
		return assertion(`rhs is of type {typeof(rhs)}, not buffer`, stackdepth)
	end

	if negate then
		if buffer.len(lhs) ~= buffer.len(rhs) then
			return nil
		end
		for offset = 0, buffer.len(lhs) - 1 do
			if buffer.readu8(lhs, offset) ~= buffer.readu8(rhs, offset) then
				return nil
			end
		end
		return assertion("expected buffers to not be equal", stackdepth, true)
	end

	if buffer.len(lhs) ~= buffer.len(rhs) then
		return assertion("buffers are of unequal length", stackdepth)
	end

	local len = buffer.len(lhs)
	for offset = 0, len - 1 do
		local left = buffer.readu8(lhs, offset)
		local right = buffer.readu8(rhs, offset)

		if left ~= right then
			return assertion(
				string.format("lhs[%d] = %02x, but rhs[%d] = %02x", offset, left, offset, right),
				stackdepth
			)
		end
	end
	return nil
end

local function eq(negate: boolean, lhs: unknown, rhs: unknown, msg: string?): Failure?
	local stackdepth = 4

	if negate then
		if lhs == rhs then
			return assertion(msg or `expected {formatValue(lhs)} to not equal {formatValue(rhs)}`, nil, true)
		end
		if typeof(lhs) ~= typeof(rhs) then
			return nil
		end
		if typeof(lhs) == "buffer" then
			return buffereq(negate, lhs :: buffer, rhs :: buffer, stackdepth + 1)
		end
		if typeof(lhs) == "table" then
			return tableeq(negate, lhs :: { [any]: any }, rhs :: { [any]: any }, stackdepth + 1)
		end
		return nil
	end

	if lhs == rhs then
		return nil
	end
	if typeof(lhs) ~= typeof(rhs) then
		return assertion(msg or `lhs is of type {typeof(lhs)}, but rhs is of type {typeof(rhs)}`)
	end
	if typeof(lhs) == "buffer" then
		return buffereq(negate, lhs :: buffer, rhs :: buffer, stackdepth + 1)
	end
	if typeof(lhs) == "table" then
		return tableeq(negate, lhs :: { [any]: any }, rhs :: { [any]: any }, stackdepth + 1)
	end
	return assertion(msg or `{lhs} ~= {rhs}`)
end

local function throwsWith<T...>(negate: boolean, with: any, func: (T...) -> ...unknown, ...: T...): Failure?
	local success, err = pcall(func, ...)

	if negate then
		if success then
			return nil
		end
		local actualErrorMessage = tostring(err)
		if typeof(with) == "string" then
			if not stringext.hasSuffix(actualErrorMessage, with) then
				return nil
			end
			return assertion(`Expected function to not throw error with suffix "{with}", but it did`, nil, true)
		else
			return eq(true, err, with, `Expected function to not throw error "{formatValue(with)}", but it did`)
		end
	end

	if success then
		return assertion(`Expected function to throw/raise error.`)
	end

	local actualErrorMessage = tostring(err)
	if typeof(with) == "string" then
		if not stringext.hasSuffix(actualErrorMessage, with) then
			return assertion(`Expected suffix of error message "{with}", but got "{actualErrorMessage}"`)
		end
	else
		return eq(false, err, with, `Expected error "{with}", but got "{formatValue(err)}"`)
	end

	return nil
end

local function strContains(
	negate: boolean,
	haystack: string,
	needle: string,
	instances: number?,
	msg: string?
): Failure?
	if negate then
		if instances == nil then
			if haystack:find(needle, 1, true) ~= nil then
				return assertion(if msg then msg else `Expected "{haystack}" to not contain "{needle}".`, nil, true)
			end
			return nil
		end

		if instances <= 0 then
			return assertion("instances must be greater than 0")
		end

		if #haystack:split(needle) == instances + 1 then
			return assertion(
				if msg then msg else `Expected "{haystack}" to not contain "{needle}" {instances} times.`,
				nil,
				true
			)
		end
		return nil
	end

	if instances == nil then
		if haystack:find(needle, 1, true) == nil then
			return assertion(if msg then msg else `Expected "{haystack}" to contain "{needle}".`)
		end
		return nil
	end

	if instances <= 0 then
		return assertion("instances must be greater than 0")
	end

	if #haystack:split(needle) ~= instances + 1 then
		return assertion(if msg then msg else `Expected "{haystack}" to contain "{needle}" {instances} times.`)
	end

	return nil
end

local function reqassert<T...>(req: (boolean, T...) -> Failure?, negate: boolean?): (T...) -> Failure?
	return function(...): Failure?
		local result: Failure? = req(negate == true, ...)
		if result ~= nil then
			error(result)
		end
		return nil
	end
end

-- `never` contains inversions for assertions without an explicit negative helper.
local assertNegation = table.freeze({
	eq = reqassert(eq, true),
	throws = reqassert(throws, true),
	throwsWith = reqassert(throwsWith, true),
	strContains = reqassert(strContains, true),
	that = reqassert(that, true),
})

return table.freeze({
	eq = reqassert(eq),
	neq = assertNegation.eq,
	throws = reqassert(throws),
	throwsWith = reqassert(throwsWith),
	strContains = reqassert(strContains),
	strNotContains = assertNegation.strContains,
	that = reqassert(that),
	never = assertNegation,
}) :: Asserts
