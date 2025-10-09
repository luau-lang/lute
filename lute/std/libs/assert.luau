local assert = {}

function assert.eq<T>(lhs: T, rhs: T)
	if lhs ~= rhs then
		error({ msg = `{lhs} ~= {rhs}` })
	end
end

function assert.neq<T>(lhs: T, rhs: T)
	if lhs == rhs then
		error({ msg = `{lhs} == {rhs}` })
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

-- Deep table comparison helper
local function tablesEqual(t1: any, t2: any, path: string): (boolean, string?)
	if type(t1) ~= "table" or type(t2) ~= "table" then
		if t1 ~= t2 then
			return false, `lhs{path} = {formatValue(t1)} but rhs{path} = {formatValue(t2)}`
		end
		return true, nil
	end
	-- Check all keys in t1
	for k, v1 in t1 do
		local v2 = t2[k]
		local newPath = if path == "" then `[{k}]` else `{path}[{k}]`

		-- Check if key exists in t2
		if v2 == nil and t2[k] == nil then
			return false, `lhs{newPath} = {formatValue(v1)} but rhs{newPath} does not exist`
		end

		local equal, msg = tablesEqual(v1, v2, newPath)
		if not equal then
			return false, msg
		end
	end

	-- Check for keys in t2 that aren't in t1
	for k, v in t2 do
		if t1[k] == nil then
			local newPath = if path == "" then `[{k}]` else `{path}[{k}]`
			return false, `rhs{newPath} = {formatValue(v)} but lhs{newPath} does not exist`
		end
	end

	return true, nil
end

-- Table equality assertion with deep comparison
function assert.tableeq(lhs: { [any]: any }, rhs: { [any]: any })
	local equal, msg = tablesEqual(lhs, rhs, "")
	if not equal then
		error({ msg = msg or "tables are not equal" })
	end
end

export type Asserts = typeof(assert)

return table.freeze(assert)
