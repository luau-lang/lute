--!strict
-- @std/luau
-- stdlib for `@lute/luau`
-- Provides utilities for parsing and compiling Luau source code

local luteLuau = require("@lute/luau")

local fs = require("@lute/fs")
local path = require("@std/path")

local luau = {}

export type Bytecode = luteLuau.Bytecode

function luau.compile(source: string): Bytecode
	return luteLuau.compile(source)
end

function luau.load(bytecode: Bytecode, chunkname: string?, env: { [any]: any }?): (...any) -> ...any
	return luteLuau.load(bytecode, if chunkname ~= nil then `@{chunkname}` else "=luau.load", env)
end

function luau.loadModule(requirePath: path.pathlike, env: { [any]: any }?): any
	local requirePathStr = if typeof(requirePath) == "string" then requirePath else path.format(requirePath)

	local migrationHandle = fs.open(requirePathStr, "r")

	local migrationBytecode = luau.compile(fs.read(migrationHandle))

	fs.close(migrationHandle)

	return luau.load(migrationBytecode, requirePathStr, env)()
end

export type TypePack = luteLuau.TypePack

function luau.typeofmodule(modulepath: path.pathlike): TypePack?
	local modulePathStr = if typeof(modulepath) == "string" then modulepath else path.format(modulepath)

	return luteLuau.typeofmodule(modulePathStr)
end

function luau.resolveModule(modulepath: string, frompath: path.pathlike): path.pathlike
	local frompathString = if typeof(frompath) == "string" then frompath else path.format(frompath)
	return luteLuau.resolveModule(modulepath, `@{frompathString}`)
end

return table.freeze(luau)
