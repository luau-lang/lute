export type array<T> = { T }
export type dictionary<T> = { [string]: T }

local function map<K, A, B>(table: { [K]: A }, f: (A) -> B): { [K]: B }
	local new = {}

	for k, v in table do
		new[k] = f(v)
	end

	return new
end

local function filter<K, V>(table: { [K]: V }, predicate: (V) -> boolean): { [K]: V }
	local new = {}

	for k, v in table do
		if predicate(v) then
			new[k] = v
		end
	end

	return new
end

local function fold<K, V, A>(table: { [K]: V }, f: (A, V) -> A, initial: A): A
	local acc = initial

	for _, v in table do
		acc = f(acc, v)
	end

	return acc
end

function isArray(tbl: {})
	if type(tbl) ~= "table" then
		return false
	end

	for key, _ in tbl do
		if type(key) ~= "number" then
			return false
		end
	end

	return true
end

function merge(table: {}, table2: {})
	local isAnArray = isArray(table) and isArray(table2)
	if isAnArray then
		for _, value in table2 do
			table[#table + 1] = value
		end
	else
		for key, value in table2 do
			table[key] = value
		end
	end

	return table, isAnArray
end

return table.freeze({
	-- std extension for table
	map = map,
	filter = filter,
	fold = fold,
	isArray = isArray,
	merge = merge,

	-- re-exports of the table library
	clear = table.clear,
	clone = table.clone,
	concat = table.concat,
	create = table.create,
	find = table.find,
	freeze = table.freeze,
	insert = table.insert,
	isfrozen = table.isfrozen,
	maxn = table.maxn,
	move = table.move,
	pack = table.pack,
	remove = table.remove,
	sort = table.sort,
	unpack = table.unpack,
})
