--!strict
-- @std/tableext
-- stdlib for an extension of the built-in table library in Luau
-- Provides additional utility functions for table operations but does not include re-exports

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

function tableext.extend<T>(tbl: array<T>, other: array<T>)
	for _, entry in other do
		table.insert(tbl, entry)
	end
end

return table.freeze(tableext)
