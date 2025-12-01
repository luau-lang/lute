--!strict
-- @std/test/assert
-- Standard assertion library for Luau
local stringext = require("@std/stringext")

local assertions = {}

function assertions.eq<T>(lhs: T, rhs: T, msg: string?)
	if lhs ~= rhs then
		error({ msg = msg or `{lhs} ~= {rhs}` })
	end
end

function assertions.neq<T>(lhs: T, rhs: T, msg: string?)
	if lhs == rhs then
		error({ msg = msg or `{lhs} == {rhs}` })
	end
end

function assertions.errors(callback: () -> (), msg: string?)
	local success = pcall(callback)
	if success then
		error({ msg = msg or `{callback} did not throw error.` })
	end
end

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

-- Table equality assertionsion with deep comparison
function assertions.tableeq(lhs: { [unknown]: unknown }, rhs: { [unknown]: unknown })
	local equal, msg = tablesEqual(lhs, rhs, "")
	if not equal then
		error({ msg = msg or "tables are not equal" })
	end
end

function assertions.buffereq(lhs: buffer, rhs: buffer)
	if typeof(lhs) ~= "buffer" then
		error(`lhs is of type {typeof(lhs)}, not buffer`)
	end

	if typeof(rhs) ~= "buffer" then
		error(`rhs is of type {typeof(rhs)}, not buffer`)
	end

	if buffer.len(lhs) ~= buffer.len(rhs) then
		error("buffers are of unequal length")
	end

	local len = buffer.len(lhs)
	for offset = 0, len - 1 do
		local left = buffer.readu8(lhs, offset)
		local right = buffer.readu8(rhs, offset)

		if left ~= right then
			error(string.format("lhs[%d] = %02x, but rhs[%d] = %02x", offset, left, offset, right))
		end
	end
end

function assertions.erroreq<A...>(func: (A...) -> ...unknown, expectedErrorMessage: string, ...: A...)
	local success, err = pcall(func, ...)
	if success then
		error({ msg = `Function did not error as expected.` })
	end

	local actualErrorMessage = tostring(err)
	-- pcall appends filename and line number of the error, so we check suffix only
	if not stringext.hassuffix(actualErrorMessage, expectedErrorMessage) then
		error({ msg = `Expected suffix of error message "{expectedErrorMessage}", but got "{actualErrorMessage}"` })
	end
end

function assertions.strcontains(haystack: string, needle: string, msg: string?, instances: number?)
	instances = instances or 1

	assert(instances > 0, "instances must be greater than 0")

	if instances == 1 then
		if haystack:find(needle, 1, true) == nil then
			error(if msg then msg else `Expected "{haystack}" to contain "{needle}".`)
		end
	else
		if #haystack:split(needle) ~= instances + 1 then
			error(if msg then msg else `Expected "{haystack}" to contain "{needle}" {instances} times.`)
		end
	end
end

export type asserts = typeof(assertions)

return table.freeze(assertions)
