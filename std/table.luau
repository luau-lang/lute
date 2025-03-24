export type array<T> = { T }
export type dictionary<T> = { [string]: T }

local function map<K, A, B>(table: { [K]: A }, f: (A) -> B): { [K]: B }
	-- apply a function to each element of the table
	local new = {}

	for k, v in table do
		new[k] = f(v, k)
	end

	return new
end

local function filter<K, V>(table: { [K]: V }, predicate: (V) -> boolean): { [K]: V }
	-- filter the table based on a predicate
	local new = {}

	for k, v in table do
		if predicate(v) then
			new[k] = v
		end
	end

	return new
end

local function fold<K, V, A>(table: { [K]: V }, f: (A, V) -> A, initial: A): A
	-- apply a function to each element of the table, with an accumulator
	local acc = initial

	for _, v in table do
		acc = f(acc, v)
	end

	return acc
end

local function isArray(tbl: {})
	-- are all the indexs numbers?
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

local function union(table1: {}, table2: {})
	-- combine the two tables into one
	local isAnArray = isArray(table1) and isArray(table2)
	if isAnArray then
		for _, value in table2 do
			table.insert(table1, value)
		end
	else
		for key, value in table2 do
			table1[key] = value
		end
	end

	return table1, isAnArray
end

local function count(dict)
	-- count the number of elements in the table, unlike
	-- using #tbl, this will work for dictionaries
	if isArray(dict) then
		return #dict
	end

	local n = 0
	for _ in dict do
		n += 1
	end
	return n
end

local function reverse(tbl)
	-- reverse the order of the table
	local new = {}
	if isArray(tbl) then
		for i = #tbl, 1, -1 do
			new[#new + 1] = tbl[i]
		end
	else
		error("Expected an array for table.reverse")
	end

	return new
end

local function find(t, val)
	-- For somereason defalt table.find sometimes returns nil
	for ind, v in t do
		if v == val then
			return ind
		end
	end
	return nil
end

local function difference(table1: {}, table2: {})
	-- return a new array with the elements that are in table1 but not in table2
	local new = {}

	if (not isArray(table1)) or (not isArray(table2)) then
		error("Expected two arrays for table.difference")
	end

	for _, value in table1 do
		if find(table2, value) then
			continue
		end
		table.insert(new, value)
	end

	return new
end

local function contains(table1, table2)
	-- does table1 contain all the elements of table2?
	for _, val in table2 do
		if not find(table1, val) then
			return false
		end
	end
	return true
end

local function set(table1)
	if not isArray(table1) then
		error("Expected an array for table.set")
	end

	-- Turn into a dict
	local new = {}
	for _, value in table1 do
		new[value] = true
	end

	-- Back to an array
	local arr = {}
	for key, _ in new do
		table.insert(arr, key)
	end

	return arr
end

return table.freeze({
	-- std extension for table
	map = map,
	filter = filter,
	fold = fold,
	isArray = isArray,
	union = union,
	count = count,
	reverse = reverse,
	difference = difference,
	contains = contains,
	set = set,

	-- re-exports of the table library
	clear = table.clear,
	clone = table.clone,
	concat = table.concat,
	create = table.create,
	find = find,
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
