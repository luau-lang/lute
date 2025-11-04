--!strict
-- @std/table
-- stdlib for the built-in table library in Luau
-- Provides additional utility functions for table operations

local tablelib = {}

export type array<T> = { T }
export type dictionary<T> = { [string]: T }

function tablelib.map<K, A, B>(table: { [K]: A }, f: (A) -> B): { [K]: B }
	local new = {}

	for k, v in table do
		new[k] = f(v)
	end

	return new
end

function tablelib.filter<K, V>(table: { [K]: V }, predicate: (V) -> boolean): { [K]: V }
	local new = {}

	for k, v in table do
		if predicate(v) then
			new[k] = v
		end
	end

	return new
end

function tablelib.fold<K, V, A>(table: { [K]: V }, f: (A, V) -> A, initial: A): A
	local acc = initial

	for _, v in table do
		acc = f(acc, v)
	end

	return acc
end

function tablelib.extend<T>(tbl: array<T>, other: array<T>)
	for _, entry in other do
		table.insert(tbl, entry)
	end
end

-- re-exports
tablelib.clear = table.clear
tablelib.clone = table.clone
tablelib.concat = table.concat
tablelib.create = table.create
tablelib.find = table.find
tablelib.freeze = table.freeze
tablelib.insert = table.insert
tablelib.isfrozen = table.isfrozen
tablelib.maxn = table.maxn
tablelib.move = table.move
tablelib.pack = table.pack
tablelib.remove = table.remove
tablelib.sort = table.sort
tablelib.unpack = table.unpack

return table.freeze(tablelib)
