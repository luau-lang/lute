-- run with lute transform tools/sort_requires.luau globpath
local syntax_utils = require("@std/syntax/utils")
local pp = require("@std/syntax/printer")
local syntax = require("@std/syntax")
local fs = require("@std/fs")
local path = require("@std/path")

type AstStat = syntax.AstStat

local GROUP_ORDER: { [string]: number } = {
	["@lute/"] = 1,
	["@std/"] = 2,
	["@batteries/"] = 3,
	["@self/"] = 4,
}

local function getGroupOrder(path: string): (string?, number)
	for prefix, order in GROUP_ORDER do
		if path:sub(1, #prefix) == prefix then
			return prefix, order
		end
	end
	return nil, 5
end

type RequireDetail = { node: syntax.AstNode, path: string, name: string, order: number }

local function isRequireStatement(stat: syntax.AstStat): boolean
	if stat.tag ~= "local" then
		return false
	end
	if #stat.values == 0 then
		return false
	end
	return syntax_utils.isRequireCall(stat.values[1].node) ~= nil
end

-- assumes you've run 'isRequireStatement' in your query
local function extractRequireDetail(stat: syntax.AstStatLocal): RequireDetail
	local node: syntax.AstExpr = stat.values[1].node
	assert(node ~= nil)
	assert(node.tag == "call")
	assert(node.kind == "expr")
	assert(node.arguments[1] ~= nil)
	assert((node.arguments[1] :: any).tag == "string")

	local name: string = stat.variables[1].node.name.text
	local path = (node.arguments[1].node :: any).token.text
	local _prefix, order = getGroupOrder(path)
	return { node = stat, path = path, name = name, order = order }
end

local function transform(ctx)
	local root: syntax.AstStatBlock = ctx.parseresult.root

	-- Find contiguous block of require statements from the top
	local requireStats: { RequireDetail } = {}
	local required = {}
	for _, stat in root.statements do
		if isRequireStatement(stat :: syntax.AstStat) then
			print("found require")
			local requireDetail = extractRequireDetail(stat :: syntax.AstStatLocal)
			table.insert(requireStats, requireDetail)
			required[stat] = true
		else
			break
		end
	end

	-- Sort: by group order, then alphabetically by path
	table.sort(requireStats, function(a: RequireDetail, b)
		if a.order ~= b.order then
			return a.order < b.order
		end

		return a.path < b.path
	end)

	-- Replace the require block in the source
	-- compute a shuffle from [st, req, st, req ...] -> [req, req, st, st]

	local buf = {}

	for i, st in requireStats do
		local v = pp.printNode(st.node)
		table.insert(buf, v)
		if i + 1 <= #requireStats and st.order ~= requireStats[i + 1].order then
			table.insert(buf, "\n")
		end
	end

	for _, st in root.statements do
		if required[st] ~= nil then
			continue
		end
		table.insert(buf, pp.printNode(st))
	end

	-- We have to do this because this currently inserts extra trivia for comments

	local fmt = table.concat(buf, "")
	print(fmt)
	fs.writeStringToFile(path.parse(ctx.path), fmt)
	return {}
end

return transform
