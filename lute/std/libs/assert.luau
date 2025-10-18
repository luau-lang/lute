local assertions = {}

function assertions.eq<T>(lhs: T, rhs: T)
	if lhs ~= rhs then
		error({ msg = `{lhs} ~= {rhs}` })
	end
end

function assertions.neq<T>(lhs: T, rhs: T)
	if lhs == rhs then
		error({ msg = `{lhs} == {rhs}` })
	end
end

function assertions.throwserror(callback: () -> ())
	local success = pcall(callback)
	if success then
		error({ msg = `{callback} did not throw error.` })
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

export type Asserts = typeof(assertions)

return table.freeze(assertions)
