local luau = require("@lute/luau")
local Transform = require("@std/syntax/transform")
local utils = require("./utils")
local printer = require("@std/syntax/printer")
local queryUtils = require("@std/syntax/utils")

local function mount(t: Transform.transform): boolean
	-- select all statements with mount calls
	local mountStatements = t:findallfromroot(t.__parseresult.root, function(node)
		if not (queryUtils.isStatLocal(node) or queryUtils.isStatAssign(node)) then
			return nil
		end
		local mount = t:findallfromroot(node, function(n)
			local mountCall = queryUtils.isExprCall(n) and n.func.tag == "indexname" and n.func.index.text == "mount"
			return if mountCall then node else nil
		end)

		return if #mount.nodes > 0 then node else nil
	end)

	if #mountStatements.nodes == 0 then
		return false
	end

	mountStatements:replace(function(mountStatement: luau.AstStatLocal | luau.AstStatAssign)
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

	return true
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

local function Portal(node: luau.AstExprCall)
	local targetTable = node.arguments[2].node :: luau.AstExprTable
	-- extract value of
	local targetArg
	for _, entry in targetTable.entries do
		if entry.key and entry.key.text and entry.key.text == "target" then
			targetArg = printer.printnode(entry.value :: any)
		end
	end
	local childrenArg = printer.printnode(node.arguments[3].node :: any)

	if not targetArg then
		return
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
	local t = Transform.new(parseresult)
	local needsReactRequire, needsReactRobloxRequire = false, false

	-- convert statements
	mount(t)

	-- convert calls
	t:findallfromroot(ast, queryUtils.isExprCall)
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
		:foreach(function(node)
			local funcName = node.func.index.text
			local firstCallArg = node.arguments[1].node
			local isRoactPortal = firstCallArg.tag == "indexname" and firstCallArg.index.text == "Portal"

			if ReactRobloxFunctionTransforms[funcName] or isRoactPortal then
				needsReactRobloxRequire = true
			else
				needsReactRequire = true
			end

			t.replacements[node :: any] = if isRoactPortal
				then callMigrations["Portal"](node)
				else callMigrations[funcName](node)
		end)

	-- convert indexname
	utils.transformLibraryAccess(t, ast, "Roact", function(_, index)
		return `React.{index.text}`
	end)

	-- convert index-exprs
	t:findallfromroot(ast, queryUtils.isExprTable):foreach(function(node: luau.AstExprTable)
		for _, entry in node.entries do
			if entry.kind ~= "general" or entry.key and entry.key.tag ~= "indexname" then
				continue
			end
			local key = entry.key
			local keyRepl
			if key.index.text == "Children" then
				keyRepl = ReactPropsTransforms["Roact.Children"](key)
			elseif key.index.text == "Ref" then
				keyRepl = ReactPropsTransforms["Roact.Ref"](key)
			end
			if keyRepl then
				needsReactRequire = true
				-- couldn't replace full entry, so went with this
				t.replacements[key :: any] = keyRepl
				t.replacements[entry.indexerclose] = ""
				t.replacements[entry.indexeropen] = ""
			end
		end
	end)

	-- convert/add requires based on all the above (if we need ReactRoblox, if we need React)
	if needsReactRequire or needsReactRobloxRequire then
		local roactRequire = utils.getRequireStatements(ast, "Roact").nodes[1]
		local requireCall = roactRequire.values[1].node
		local requiredModule = requireCall.arguments[1].node
		if needsReactRequire and needsReactRobloxRequire then
			-- get PackagesRoot
			local packagesRoot = printer.printnode(requiredModule.expression)
			t.replacements[roactRequire] =
				`local React = require({packagesRoot}.React)\nlocal ReactRoblox = require({packagesRoot}.ReactRoblox)\n`
			-- replace whole statement
		else
			-- just replace index and local var name of needed package
			t:findallfromroot(requiredModule :: any, queryUtils.isExprIndexName)
				:map(function(node)
					return node.index
				end)
				:replace(function(node)
					return if needsReactRequire then "React" else "ReactRoblox"
				end)

			local roactVar = roactRequire.variables[1].node
			t:findallfromroot(roactVar :: any, queryUtils.isToken):replace(function(node: luau.Token)
				return if needsReactRequire then "React" else "ReactRoblox"
			end)
		end
	end

	return t:transform()
end

return {
	transform = transform,
	cases = require("./roactToReact/cases"),
}

--[[

High level notes:

- upwards navigation is rly useful; in this codemod, it'd be a lot easier / more performant to query for each function call (generally), update all those that are migrated accordingly (if we have upwards nav
  we can get the statement by walking up tree from the call node). unfortunately, bc some of the migrations require the whole call statement (i.e local var = call),
  we cannot do this and have to query for statements for those transforms that require the whole statement context, and separately query for calls for those transforms that only need the call node

- I'm not sure of a good way around this one, just a general performance concern, it's tricky to vary operations between node world / string world.
  When operating on a node, it is not uncommon to want to re-use parts of that node in your transformed output; currently, this will require:
  	- for string transform: parsing the node into a string, and interpolating into your returned replacement
	- for node transform: cloning node so it's mutable, updating accordingly (even more impractical, would never do this, just pointing out you CAN)

  This incurs exponential complexity, as for each node we visit and transform in our query, we require at least an additional pass (of part of the node) to print. 

- nit: annoying to have to query (visit whole tree), and get nodes I want with a predicate (this also requires additional pass: one pass to get nodes fulfilling predicate; subsequent to operate on them)
]]
