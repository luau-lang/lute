--!strict
-- Canonical serializer for CST trees.
--
-- Produces a deterministic textual representation of a CST value so that the
-- reference parser (@lute/syntax/parser) and our pure-Luau parser can be
-- compared for exact structural equality. Metatables (Span, Punctuated) are
-- ignored: tables are walked with raw iteration (`next`) so that only the
-- underlying data is compared.

local function escape(s: string): string
	return (string.gsub(s, "[\\\"\n\r\t]", {
		["\\"] = "\\\\",
		['"'] = '\\"',
		["\n"] = "\\n",
		["\r"] = "\\r",
		["\t"] = "\\t",
	}))
end

local serializeValue

local function serializeTable(t: { [any]: any }, out: { string }, indent: string)
	-- Collect raw keys (ignoring any __iter metamethod).
	local keys: { any } = {}
	local k = next(t)
	while k ~= nil do
		table.insert(keys, k)
		k = next(t, k)
	end

	table.sort(keys, function(a, b): boolean
		local ta, tb = type(a), type(b)
		if ta ~= tb then
			return ta < tb
		end
		if ta == "number" then
			return (a :: number) < (b :: number)
		end
		return tostring(a) < tostring(b)
	end)

	if #keys == 0 then
		table.insert(out, "{}")
		return
	end

	table.insert(out, "{\n")
	local inner = indent .. "  "
	for _, key in keys do
		table.insert(out, inner)
		table.insert(out, "[")
		table.insert(out, serializeValue(key, inner))
		table.insert(out, "] = ")
		table.insert(out, serializeValue(t[key], inner))
		table.insert(out, "\n")
	end
	table.insert(out, indent)
	table.insert(out, "}")
end

function serializeValue(v: any, indent: string): string
	local t = type(v)
	if t == "table" then
		local out: { string } = {}
		serializeTable(v, out, indent)
		return table.concat(out)
	elseif t == "string" then
		return '"' .. escape(v) .. '"'
	elseif t == "number" then
		-- Normalize integer-valued floats so 1 and 1.0 compare equal.
		if v == math.floor(v) and v == v and v ~= math.huge and v ~= -math.huge then
			return string.format("%d", v)
		end
		return tostring(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "nil" then
		return "nil"
	else
		return "<" .. t .. ">"
	end
end

local function serialize(v: any): string
	return serializeValue(v, "")
end

return serialize
