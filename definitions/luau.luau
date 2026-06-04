-- lute-lint-global-ignore(unused_variable)

local luau = {}

--- Compiled Luau bytecode produced by `luau.compile`.
export type Bytecode = { bytecode: string }

--- Compiles Luau `source` to bytecode.
function luau.compile(source: string): Bytecode
	error("not implemented")
end

--- Loads `bytecode` into a callable function. `chunkname` names the chunk for error messages. An optional `env` table can override the global environment.
function luau.load(bytecode: Bytecode, chunkname: string, env: { [any]: any }?): (...any) -> ...any
	error("not implemented")
end

--- Resolves the require path `path` relative to `fromchunkname`, returning the absolute path.
function luau.resolveModule(path: string, fromchunkname: string): string
	error("not implemented")
end

--- A resolved Luau type, as returned by `typeofModule`.
export type Type = {
	tag: "nil"
		| "unknown"
		| "never"
		| "any"
		| "boolean"
		| "number"
		| "string"
		| "buffer"
		| "thread"
		| "singleton"
		| "negation"
		| "union"
		| "intersection"
		| "table"
		| "function"
		| "extern"
		| "generic",

	-- for singleton type
	value: string | boolean | nil,

	-- for negation type
	inner: Type,

	-- for union and intersection types
	components: { Type },

	-- for table type
	properties: { [string]: { read: Type?, write: Type? } },
	indexer: { index: Type }?, -- TODO: add readresult and writeresult
	-- TODO: readindexer: { index: type, result: type } }?,
	-- TODO: writeindexer: { index: type, result: type } }?,
	metatable: Type?,

	-- for function type
	parameters: TypePack,
	argnames: { string? },
	returns: TypePack,
	generics: { Type },
	genericpacks: { TypePack },

	-- for extern type
	-- 'properties', 'metatable' are shared with table type
	parent: Type?,

	-- for generic type
	name: string,
	ispack: boolean,
}

--- A resolved Luau type pack, as returned by `typeofModule`.
export type TypePack = {
	tag: "typepack" | "variadic" | "generic",
	head: { Type }?,
	tail: TypePack?,

	-- for variadic type packs
	type: Type,
	hidden: boolean,

	-- for generic type packs
	name: string,
	ispack: boolean,
}

--- Returns the type pack representing the return types of the module at `modulepath`, or `nil` if unavailable.
function luau.typeofModule(modulepath: string): TypePack?
	error("not implemented")
end

return luau
