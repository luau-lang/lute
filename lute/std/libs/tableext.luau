--!strict
-- @std/tableext
-- stdlib for an extension of the built-in table library in Luau
-- Provides additional utility functions for table operations

local tableext = {}

function tableext.map<K, A, B>(table: { [K]: A }, f: (A) -> B): { [K]: B }
	local new = {}

	for k, v in table do
		new[k] = f(v)
	end

	return new
end

function tableext.filter<K, V>(table: { [K]: V }, predicate: (V) -> boolean): { [K]: V }
	local new = {}

	for k, v in table do
		if predicate(v) then
			new[k] = v
		end
	end

	return new
end

function tableext.extend<T>(tbl: { T }, ...: { T })
	local extensions = table.pack(...)
	extensions.n = nil :: any
	for _, extension in extensions do
		for _, entry in extension do
			table.insert(tbl, entry)
		end
	end
end

function tableext.combine<K, V>(tbl: { [K]: V }, ...: { [K]: V }): { [K]: V }
	local tables = table.pack(...)
	tables.n = nil :: any
	for _, tocombine in tables do
		for key, val in tocombine do
			tbl[key] = val
		end
	end
	return tbl
end

function tableext.keys<K, V>(tbl: { [K]: V }): { K }
	local keys = {}
	for k, _ in tbl do
		table.insert(keys, k)
	end
	return keys
end

function tableext.reverse<T>(tbl: { T }, inplace: boolean?)
	local new = if inplace then tbl else {}
	local i, j = 1, #tbl
	while i <= j do
		new[i], new[j] = tbl[j], tbl[i]
		i += 1
		j -= 1
	end
	return new
end

return table.freeze(tableext)
