--!strict
-- @std/luau
-- stdlib for `@lute/luau`
-- Provides utilities for parsing and compiling Luau source code

local luteLuau = require("@lute/luau")

local fs = require("@lute/fs")
local path = require("@std/path")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

local luau = {}

export type bytecode = luteLuau.Bytecode

export type TypePack = luteLuau.TypePack

export type RequireNode = {
	resolvedPath: string?,
	requireStr: string?,
	requireAst: luteLuau.AstExprCall,
}

function luau.compile(source: string): bytecode
	return luteLuau.compile(source)
end

function luau.load(bytecode: bytecode, chunkname: string?, env: { [any]: any }?): (...any) -> ...any
	return luteLuau.load(bytecode, if chunkname ~= nil then `@{chunkname}` else "=luau.load", env)
end

function luau.loadModule(requirePath: path.pathlike, env: { [any]: any }?): any
	local requirePathStr = if typeof(requirePath) == "string" then requirePath else path.format(requirePath)

	local migrationHandle = fs.open(requirePathStr, "r")

	local migrationBytecode = luau.compile(fs.read(migrationHandle))

	fs.close(migrationHandle)

	return luau.load(migrationBytecode, requirePathStr, env)()
end

function luau.typeofmodule(modulepath: path.pathlike): TypePack?
	local modulePathStr = if typeof(modulepath) == "string" then modulepath else path.format(modulepath)

	return luteLuau.typeofmodule(modulePathStr)
end

function luau.resolveModule(modulepath: string, frompath: path.pathlike): path.pathlike
	local frompathString = if typeof(frompath) == "string" then frompath else path.format(frompath)
	return luteLuau.resolveModule(modulepath, `@{frompathString}`)
end

function luau.requires(filePath: path.pathlike): { RequireNode }
	local filePathStr = if typeof(filePath) == "string" then filePath else path.format(filePath)

	local handle = fs.open(filePathStr, "r")
	local source = fs.read(handle)
	fs.close(handle)

	local ast = luteLuau.parse(source)

	-- FIXME: сhange this if PR #887 is merged
	local requireCalls = query.findallfromroot(ast, utils.isExprCall):filter(function(call)
		return call.func.tag == "global" and call.func.name.text == "require"
	end)

	return requireCalls:maptoarray(function(call: luteLuau.AstExprCall): RequireNode?
		local argNode = call.arguments[1].node
		if argNode == nil then
			return nil
		end

		local requireStr: string? = nil
		if argNode.tag == "string" then
			requireStr = (argNode :: luteLuau.AstExprConstantString).token.text
		end

		local resolved: string? = nil
		if requireStr ~= nil then
			local ok, result = pcall(luteLuau.resolveModule, requireStr, `@{filePathStr}`)
			if ok then
				resolved = result
			end
		end

		return {
			resolvedPath = resolved,
			requireStr = requireStr,
			requireAst = call,
		}
	end)
end

return table.freeze(luau)
