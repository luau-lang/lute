local luau = require("@lute/luau")
local types = require("@std/syntax/types")
local query = require("@std/syntax/query")
local utils = require("./utils")
local printer = require("@std/syntax/printer")
local tableext = require("@std/tableext")
local queryUtils = require("@std/syntax/utils")

local function mount(block: luau.AstStatBlock): types.replacements
	-- select all statements with mount calls
	local mountStatements = query.findallfromroot(block, function(node)
		if not (queryUtils.isStatLocal(node) or queryUtils.isStatAssign(node)) then
			return nil :: any
		end

		local isMount = query.findallfromroot(node, queryUtils.isExprCall):exists(function(n)
			if n.func.tag == "indexname" and n.func.index.text == "mount" then
				return true
			end
			return false
		end)

		return if isMount then node else nil
	end)

	if #mountStatements.nodes == 0 then
		return {}
	end

	return mountStatements:replace(function(mountStatement: luau.AstStatLocal | luau.AstStatAssign)
		-- get mounted variable
		local mountedVar = printer.printnode(mountStatement.variables[1].node :: any)
		local mountCall = mountStatement.values[1].node :: luau.AstExprCall
		local mountCallArgs = mountCall.arguments
		local elementArg = printer.printnode(mountCallArgs[1].node :: any)
		local parentArg, keyArg
		if
			mountCallArgs[2]
			and mountCallArgs[2].node
			and not queryUtils.isExprConstantNil(mountCallArgs[2].node :: any)
		then
			parentArg = printer.printnode(mountCallArgs[2].node :: any)
		else
			parentArg = 'Instance.new("Folder")'
		end
		if
			mountCallArgs[3]
			and mountCallArgs[3].node
			and not queryUtils.isExprConstantNil(mountCallArgs[3].node :: any)
		then
			keyArg = printer.printnode(mountCallArgs[3].node :: any)
		else
			keyArg = '"ReactRoot"'
		end

		local mountSetup =
			`local root = ReactRoblox.createRoot(Instance.new("Folder"))\nlocal actualParent = {parentArg}\nlocal actualKey = {keyArg}`
		local mount = ([[ReactRoblox.act(function()
	root:render(ReactRoblox.createPortal({ [actualKey] = %s } :: any, actualParent))
end)
local %s = { root = root, parent = actualParent, key = actualKey }]]):format(elementArg, mountedVar)
		return mountSetup .. "\n" .. mount
	end)
end

local function update(node: luau.AstExprCall)
	-- update is a call, no statement, so we can expect to receive the exact call here

	local instanceArg, elementArg =
		printer.printnode(node.arguments[1].node :: any), printer.printnode(node.arguments[2].node :: any)

	local newUpdate = [[ReactRoblox.act(function()
	%s.root:render(ReactRoblox.createPortal({ [%s.key] = %s } :: any, %s.parent))
end)]] :: any
	return newUpdate:format(instanceArg, instanceArg, elementArg, instanceArg)
end

local function unmount(node: luau.AstExprCall)
	-- we can just expect the call here
	local instanceArg = printer.printnode(node.arguments[1].node :: any)
	return `{instanceArg}.root:unmount()`
end

local function Portal(node: luau.AstExprCall): string?
	local targetTable = node.arguments[2].node :: luau.AstExprTable
	-- extract value of
	local targetArg
	for _, entry in targetTable.entries do
		entry = entry :: luau.AstExprTableItemGeneral
		if entry.key and queryUtils.isToken(entry.key) and entry.key.text == "target" then
			targetArg = printer.printnode(entry.value :: any)
		end
	end
	local childrenArg = printer.printnode(node.arguments[3].node :: any)

	if not targetArg then
		return nil
	end

	return `ReactRoblox.createPortal({childrenArg}, {targetArg})`
end

local ReactRobloxFunctionTransforms = {
	["mount"] = mount,
	["update"] = update,
	["unmount"] = unmount,
	["Portal"] = Portal,
}

-- everything not covered by the ReactRoblox transforms above migrates to React (most cases are just Roact.func -> React.func, with some exceptions outlined in below table)
local function oneChild(node: luau.AstExprCall)
	local childArg = printer.printnode(node.arguments[1].node :: any)

	local ReactOneChild =
		[[if not %s or not select(2, next(%s)) or next(%s, table.pack(select(1, next(%s) :: string))[1])
	then nil
else React.Children.only(select(2, next(%s) :: any))]]

	return (ReactOneChild :: any):format(childArg, childArg, childArg, childArg, childArg)
end
local function createFragment(node: luau.AstExprCall)
	local childArg = printer.printnode(node.arguments[1].node :: any)

	return `React.createElement(React.Fragment, nil, {childArg})`
end

local function indexExprKeyToStringKey(expr: string, index: string, repl: string)
	return function(node: luau.AstExprIndexName): string?
		if
			node.index.text == index
			and queryUtils.isExprLocal(node.expression) ~= nil
			and (node.expression :: luau.AstExprLocal).token.text == expr
		then
			return repl
		else
			return nil
		end
	end
end

local ReactPropsTransforms = {
	["Roact.Children"] = indexExprKeyToStringKey("Roact", "Children", "children"),
	["Roact.Ref"] = indexExprKeyToStringKey("Roact", "Ref", "ref"),
}

local callMigrations = {
	["update"] = update,
	["unmount"] = unmount,
	["Portal"] = Portal,
	["oneChild"] = oneChild,
	["createFragment"] = createFragment,
} :: { [string]: (luau.AstExprCall) -> string }

local function transform(ctx)
	local parseresult = ctx.parseresult
	local ast = parseresult.root
	local needsReactRequire, needsReactRobloxRequire = false, false

	-- convert statements
	local fullStatementRepl = mount(ast)

	-- convert calls
	local callRepl = query
		.findallfromroot(ast, queryUtils.isExprCall)
		:filter(function(node: luau.AstExprCall)
			local func = node.func
			if func.tag ~= "indexname" then
				return false
			end
			if not queryUtils.isExprLocal(func.expression) then
				return false
			end

			local needsMigration = func.expression.token.text == "Roact" and callMigrations[func.index.text] ~= nil
			-- specifically catch Roact.Portal
			local firstCallArg = node.arguments[1].node
			local isRoactPortal = firstCallArg.tag == "indexname" and firstCallArg.index.text == "Portal"
			needsMigration = needsMigration or isRoactPortal
			return needsMigration
		end)
		:replace(function(node)
			local funcName = node.func.index.text
			local firstCallArg = node.arguments[1].node
			local isRoactPortal = firstCallArg.tag == "indexname" and firstCallArg.index.text == "Portal"

			if ReactRobloxFunctionTransforms[funcName] or isRoactPortal then
				needsReactRobloxRequire = true
			else
				needsReactRequire = true
			end

			return if isRoactPortal then callMigrations["Portal"](node) else callMigrations[funcName](node)
		end)

	-- convert indexname
	local libIndexNameRepl = utils.transformLibraryAccess(ast, "Roact", function(_, index)
		return `React.{index.text}`
	end)

	-- convert index-exprs
	local libIndexExprRepl = query
		.findallfromroot(ast, queryUtils.isExprTableItem)
		:filter(function(entry)
			if entry.kind ~= "general" or entry.key and entry.key.tag ~= "indexname" then
				return false
			end

			local key = entry.key
			return key.index.text == "Children" or key.index.text == "Ref"
		end)
		:replace(function(entry: any) -- had to any caste this to shut up type solver
			local key = entry.key :: luau.AstExprIndexName
			local keyRepl
			if key.index.text == "Children" then
				keyRepl = ReactPropsTransforms["Roact.Children"](key)
			elseif key.index.text == "Ref" then
				keyRepl = ReactPropsTransforms["Roact.Ref"](key)
			end
			local entryValue = printer.printnode(entry.value)
			if keyRepl then
				needsReactRequire = true
				-- couldn't replace full entry, so went with this
				return `{keyRepl} = {entryValue},` :: any
			end
			return entry
		end)

	-- convert/add requires based on all the above (if we need ReactRoblox, if we need React)
	local addedRequiresRepl = {}
	if needsReactRequire or needsReactRobloxRequire then
		local roactRequire = utils.getRequireStatements(ast, "Roact").nodes[1]
		local requireCall = roactRequire.values[1].node :: luau.AstExprCall
		local requiredModule = requireCall.arguments[1].node :: luau.AstExprIndexName
		if needsReactRequire and needsReactRobloxRequire then
			-- get PackagesRoot
			local packagesRoot = printer.printnode(requiredModule.expression :: any)
			addedRequiresRepl[roactRequire] =
				`local React = require({packagesRoot}.React)\nlocal ReactRoblox = require({packagesRoot}.ReactRoblox)\n`
			-- replace whole statement
		else
			-- just replace index and local var name of needed package
			local requireArgRepl = query
				.findallfromroot(requireCall :: any, queryUtils.isExprIndexName)
				:map(function(node)
					return node.index :: any
				end)
				:replace(function(node)
					return if needsReactRequire then "React" else "ReactRoblox"
				end)

			local roactVar = roactRequire.variables[1].node
			local requiredVarRepl = query
				.findallfromroot(roactVar :: any, queryUtils.isToken)
				:replace(function(node: luau.Token)
					return if needsReactRequire then "React" else "ReactRoblox"
				end)
			addedRequiresRepl = tableext.combine(requireArgRepl, requiredVarRepl)
		end
	end

	return tableext.combine(
		fullStatementRepl,
		callRepl,
		libIndexNameRepl,
		libIndexExprRepl,
		addedRequiresRepl :: types.replacements
	)
	-- return t:transform()
end

return transform
