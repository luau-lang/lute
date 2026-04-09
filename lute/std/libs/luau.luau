--!strict
-- @std/luau
-- stdlib for `@lute/luau`
-- Provides utilities for parsing and compiling Luau source code

local luteLuau = require("@lute/luau")

local fs = require("@lute/fs")
local path = require("@std/path")

local luau = {}

--- Compiled Luau bytecode produced by `luau.compile`.
export type Bytecode = luteLuau.Bytecode

--- Compiles Luau source code into bytecode.
function luau.compile(source: string): Bytecode
	return luteLuau.compile(source)
end

--- Loads `bytecode` into a callable function. `chunkname` names the chunk for error messages.
--- An optional `env` table can be provided to override the global environment for the loaded chunk.
function luau.load(bytecode: Bytecode, chunkname: string?, env: { [any]: any }?): (...any) -> ...any
	return luteLuau.load(bytecode, if chunkname ~= nil then `@{chunkname}` else "=luau.load", env)
end

--- Loads and executes the Luau file at `requirePath`, returning its result.
--- An optional `env` table can be provided to override the global environment.
function luau.loadModule(requirePath: path.Pathlike, env: { [any]: any }?): any
	local requirePathStr = if typeof(requirePath) == "string" then requirePath else path.format(requirePath)

	local migrationHandle = fs.open(requirePathStr, "r")

	local migrationBytecode = luau.compile(fs.read(migrationHandle))

	fs.close(migrationHandle)

	return luau.load(migrationBytecode, requirePathStr, env)()
end

--- A pack of Luau types (e.g. the return types of a function).
export type TypePack = luteLuau.TypePack
--- A Luau type, as returned by the type-checker.
export type Type = luteLuau.Type

--- Returns the type pack representing the return types of the module at `modulepath`, or `nil` if unavailable.
function luau.typeofModule(modulepath: path.Pathlike): TypePack?
	local modulePathStr = if typeof(modulepath) == "string" then modulepath else path.format(modulepath)

	return luteLuau.typeofModule(modulePathStr)
end

--- Resolves the require path `modulepath` relative to `frompath`, returning the absolute path.
function luau.resolveModule(modulepath: string, frompath: path.Pathlike): path.Pathlike
	local frompathString = if typeof(frompath) == "string" then frompath else path.format(frompath)
	return luteLuau.resolveModule(modulepath, `@{frompathString}`)
end

return table.freeze(luau)
