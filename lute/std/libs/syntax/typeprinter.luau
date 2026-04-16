--!strict

local types = require("./types")

type PrinterState = {
	visited: { [any]: boolean },
	cycles: { [any]: string },
	nextCycleId: number,
}

local renderType: (t: types.Type, state: PrinterState) -> string
local renderTypePack: (tp: types.TypePack?, state: PrinterState, names: { string? }?) -> string

renderType = function(t: types.Type, state: PrinterState): string
	if t.name and t.tag ~= "generic" then
		return t.name
	end

	if state.cycles[t] then
		return state.cycles[t]
	end
	if state.visited[t] then
		state.nextCycleId += 1
		local id = "t" .. state.nextCycleId
		state.cycles[t] = id
		return id
	end
	state.visited[t] = true

	local tag = t.tag

	if tag == "union" then
		local parts = {}
		local hasNil = false
		for _, comp in t.components or {} do
			if comp.tag == "nil" then
				hasNil = true
			else
				table.insert(parts, renderType(comp, state))
			end
		end
		table.sort(parts)
		local base = table.concat(parts, " | ")
		if hasNil then
			if #parts == 0 then
				return "nil"
			end
			return if #parts > 1 then `({base})?` else `{base}?`
		end
		return base
	end

	if tag == "table" or tag == "extern" then
		local parts = {}
		local keys = {}
		for name in pairs(t.properties or {}) do
			table.insert(keys, name)
		end
		table.sort(keys)

		for _, name in keys do
			local p = t.properties[name]
			if p and p.read then
				table.insert(parts, `{name}: {renderType(p.read, state)}`)
			end
		end

		if t.indexer then
			table.insert(parts, `[{renderType(t.indexer.index, state)}]: any`)
		end

		if #parts == 0 then
			return "{}"
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end

	if tag == "function" then
		local generics = {}
		-- Handle regular generics <T, U>
		for _, g in t.generics or {} do
			table.insert(generics, renderType(g, state))
		end
		-- Handle generic packs <T..., U...>
		for _, gp in t.genericpacks or {} do
			local rendered = renderTypePack(gp, state)
			-- Ensure it has the ... if it's a generic pack name
			if rendered ~= "" and not string.find(rendered, "%.%.%.$") then
				rendered = rendered .. "..."
			end
			table.insert(generics, rendered)
		end

		local params = renderTypePack(t.parameters, state, t.argnames)
		local returns = renderTypePack(t.returns, state)

		local genStr = if #generics > 0 then `<{table.concat(generics, ", ")}>` else ""
		return `{genStr}({params}) -> ({returns})`
	end

	if tag == "singleton" then
		return if typeof(t.value) == "string" then string.format("%q", t.value) else tostring(t.value)
	end

	return tag or "any"
end

renderTypePack = function(tp: types.TypePack?, state: PrinterState, names: { string? }?): string
	if not tp then
		return ""
	end

	-- If the whole pack is just a generic (T...)
	if tp.tag == "generic" then
		return (tp.name or "T") .. "..."
	end

	-- If it's a variadic pack (...any)
	if tp.tag == "variadic" then
		-- Only render "any..." if it's explicitly an "any" type,
		-- otherwise use the actual type name.
		if tp.hidden then
			return ""
		end
		local typeName = if tp.type then renderType(tp.type, state) else "any"
		return typeName .. "..."
	end

	if tp.tag == "typepack" then
		local parts = {}
		local head = tp.head or {}
		for i, t in ipairs(head) do
			local res = renderType(t, state)
			if names and names[i] then
				table.insert(parts, `{names[i]}: {res}`)
			else
				table.insert(parts, res)
			end
		end

		if tp.tail then
			local ts = renderTypePack(tp.tail, state)
			if ts ~= "" then
				local nextIdx = #head + 1
				if names and names[nextIdx] then
					table.insert(parts, `{names[nextIdx]}: {ts}`)
				else
					table.insert(parts, ts)
				end
			end
		end
		return table.concat(parts, ", ")
	end
	return ""
end

return {
	renderType = function(t: types.Type): string
		return renderType(t, { visited = {}, cycles = {}, nextCycleId = 0 })
	end,
}
