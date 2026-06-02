--!strict
-- @std/luau
-- stdlib for `@lute/luau`
-- Provides utilities for parsing and compiling Luau source code

local cst = require("@lute/syntax/cst")
local luteLuau = require("@lute/luau")
local parser = require("@lute/syntax/parser")

local fs = require("@lute/fs")
local path = require("@std/path")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")
local printer = require("@std/syntax/printer")

local luau = {}

--- Compiled Luau bytecode produced by `luau.compile`.
export type Bytecode = luteLuau.Bytecode

--- A `require(...)` call found in a source file, with its resolved absolute path and the raw require string.
export type RequireNode = {
	resolvedPath: string?,
	requirePath: string?,
	requireExpr: cst.CstExprCall,
}

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

--- A Luau type pack, representing a sequence of types.
export type TypePack = luteLuau.TypePack
--- A Luau type, representing the type of a value or expression.
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

--- Returns all `require(...)` calls found in the file at `filePath`, with resolved absolute paths where available.
function luau.requires(filePath: path.Pathlike): { RequireNode }
	local filePathStr = if typeof(filePath) == "string" then filePath else path.format(filePath)

	local handle = fs.open(filePathStr, "r")
	local source = fs.read(handle)
	fs.close(handle)

	local cst = parser.parse(source)

	local requireCalls = query.findAllFromRoot(cst, utils.isRequireCall)

	return requireCalls:mapToArray(function(call: cst.CstExprCall): RequireNode?
		local argNode = call.arguments[1]
		if argNode == nil then
			return nil
		end

		local content: string? = nil
		if argNode.tag == "string" then
			content = (argNode :: cst.CstExprConstantString).value.text
		else
			content = printer.printNode(argNode)
		end

		local resolved: string? = nil
		if content ~= nil then
			local ok, result = pcall(luteLuau.resolveModule, content, `@{filePathStr}`)
			if ok then
				resolved = result
			end
		end

		return {
			resolvedPath = resolved,
			requirePath = content,
			requireExpr = call,
		}
	end)
end

return table.freeze(luau)
