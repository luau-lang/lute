--!strict
-- @std/tableext
-- stdlib for an extension of the built-in table library in Luau
-- Provides additional utility functions for table operations

local tableext = {}

export type array<T> = { T }
export type dictionary<T> = { [string]: T }

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

function tableext.fold<K, V, A>(table: { [K]: V }, f: (A, V) -> A, initial: A): A
	local acc = initial

	for _, v in table do
		acc = f(acc, v)
	end

	return acc
end

function tableext.extend<T>(tbl: array<T>, ...: array<T>)
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

function tableext.foreach<K, V>(tbl: { [K]: V }, f: (K, V) -> ())
	for k, v in tbl do
		f(k, v)
	end
end

function tableext.keys<K, V>(tbl: { [K]: V }): { K }
	local keys = {}
	for k, _ in tbl do
		table.insert(keys, k)
	end
	return keys
end

return table.freeze(tableext)
