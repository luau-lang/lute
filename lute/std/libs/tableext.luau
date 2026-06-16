--!strict
-- @std/tableext
-- stdlib for an extension of the built-in table library in Luau
-- Provides additional utility functions for table operations

local tableext = {}

-- Functions on general tables

--- Returns a new table with the same keys as `table`, where each value has been transformed by applying `f` to it.
function tableext.map<K, A, B>(table: { [K]: A }, f: (A) -> B): { [K]: B }
	local new = {}

	for k, v in table do
		new[k] = f(v)
	end

	return new
end

--- Returns a new table containing only the key-value pairs from `table` for which `predicate` returns `true`.
function tableext.filter<K, V>(table: { [K]: V }, predicate: (V) -> boolean): { [K]: V }
	local new = {}

	for k, v in table do
		if predicate(v) then
			new[k] = v
		end
	end

	return new
end

--- Returns the first key-value pair from `table` for which `predicate` returns `true`. Returns `nil, nil` if the predicate does not hold for any value.
function tableext.find<K, V>(table: { [K]: V }, predicate: (V) -> boolean): (V?, K?)
	for k, v in table do
		if predicate(v) then
			return v, k
		end
	end
	return nil, nil
end

--- Merges all additional tables into `tbl` in order. When the same key appears in multiple tables, the value from the last table containing that key wins. Returns `tbl`.
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

--- Returns an array of all keys in `tbl`. Order is not guaranteed.
function tableext.keys<K, V>(tbl: { [K]: V }): { K }
	local keys = {}
	for k, _ in tbl do
		table.insert(keys, k)
	end
	return keys
end

-- Functions on array-like tables

--- Converts an array into a set-like table where each element maps to `true`.
@native
function tableext.toSet<T>(tbl: { T }): { [T]: true }
	local set: { [T]: true } = {}
	for _, v in tbl do
		set[v] = true
	end
	return set
end

--- Appends all elements from each additional array into `tbl` in order, mutating it in place.
function tableext.extend<T>(tbl: { T }, ...: { T }): ()
	local extensions = table.pack(...)
	extensions.n = nil :: any
	for _, extension in extensions do
		for _, entry in extension do
			table.insert(tbl, entry)
		end
	end
end

--- Returns `tbl` with its elements in reverse order. If `inplace` is `true`, reverses `tbl` in place; otherwise returns a new array.
function tableext.reverse<T>(tbl: { T }, inplace: boolean?): { T }
	local new = if inplace then tbl else {}
	local i, j = 1, #tbl
	while i <= j do
		new[i], new[j] = tbl[j], tbl[i]
		i += 1
		j -= 1
	end
	return new
end

--- Returns `true` if `predicate` returns `true` for at least one element of `arr`.
function tableext.any<T>(arr: { T }, predicate: (T) -> boolean): boolean
	for _, v in arr do
		if predicate(v) then
			return true
		end
	end
	return false
end

--- Returns `true` if `predicate` returns `true` for every element of `arr`.
function tableext.all<T>(arr: { T }, predicate: (T) -> boolean): boolean
	for _, v in arr do
		if not predicate(v) then
			return false
		end
	end
	return true
end

return table.freeze(tableext)
