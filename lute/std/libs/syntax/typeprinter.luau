--!strict
-- typeprinter.luau

local types = require("./types")

-- have a visited hashmap to avoid infinite recursion that also stores the string version of what should be printed, and when we hit a recursive type, we can just return the stored string instead of trying to render it again
-- local visitedTypes = {
--     [any] = string,
-- }

local renderType: (t: types.Type, visited: { [any]: boolean }) -> string
local renderTypePack: (tp: types.TypePack?, visited: { [any]: boolean }) -> string

renderType = function(t: types.Type, visited: { [any]: boolean }): string
	if visited[t] then
		return "<recursive>" -- TODO: better handling of recursive types
	end
	visited[t] = true

	local tag = t.tag
	if
		tag == "nil"
		or tag == "unknown"
		or tag == "never"
		or tag == "any"
		or tag == "boolean"
		or tag == "number"
		or tag == "string"
		or tag == "buffer"
		or tag == "thread"
	then
		return tag
	elseif tag == "singleton" then
        if typeof(t.value) == "string" then
            return string.format("%q", t.value) -- quote strings
        end
		return tostring(t.value)
	elseif tag == "generic" then
		return t.name
	elseif tag == "negation" then
		return "~" .. renderType(t.inner, visited)
	elseif tag == "union" then
		local parts = {}
		for _, comp in t.components do
			table.insert(parts, renderType(comp, visited))
		end
		return table.concat(parts, " | ")
	elseif tag == "intersection" then
		local parts = {}
		for _, comp in t.components do
			table.insert(parts, renderType(comp, visited))
		end
		return table.concat(parts, " & ")
	elseif tag == "table" or tag == "extern" then
		local parts = {}
		for name, prop in pairs(t.properties or {}) do
			if prop.read then
				table.insert(parts, name .. ": " .. renderType(prop.read, visited))
			end
		end
		if t.indexer then
			table.insert(parts, "[" .. renderType(t.indexer.index, visited) .. "]: any")
		end
		if #parts == 0 then
			return "{}"
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	elseif tag == "function" then
		local generics = {}
		for _, g in t.generics or {} do
			table.insert(generics, renderType(g, visited))
		end
		for _, gp in t.genericpacks or {} do
			table.insert(generics, renderTypePack(gp, visited))
		end

		local params = renderTypePack(t.parameters, visited)
		local returns = renderTypePack(t.returns, visited)

		local genericStr = if #generics > 0 then "<" .. table.concat(generics, ", ") .. ">" else ""

		return genericStr .. "(" .. params .. ") -> (" .. returns .. ")"
	end

	return "<" .. tostring(tag) .. ">"
end

renderTypePack = function(tp: types.TypePack?, visited: { [any]: boolean }): string
	if not tp then
		return ""
	end
	if visited[tp] then
		return "<recursive>"
	end
	visited[tp] = true

	if tp.tag == "typepack" then
		local parts = {}
		for _, t in tp.head or {} do
			table.insert(parts, renderType(t, visited))
		end
		if tp.tail then
			local tailStr = renderTypePack(tp.tail, visited)
			if tailStr ~= "" then
				table.insert(parts, tailStr)
			end
		end
		return table.concat(parts, ", ")
	elseif tp.tag == "variadic" then
		if tp.hidden then
			return ""
		end
		return renderType(tp.type, visited) .. "..."
	elseif tp.tag == "generic" then
		return tp.name .. "..."
	end
	return ""
end

return {
	renderType = function(t: types.Type): string
		return renderType(t, {})
	end,
	renderTypePack = function(tp: types.TypePack?): string
		return renderTypePack(tp, {})
	end,
}
