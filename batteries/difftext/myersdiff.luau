local deque = require("@batteries/collections/deque")

type EditGraphNode = {
	x: number,
	y: number,
	prev: EditGraphNode?,
}

local function editGraphNode(x: number, y: number, prev: EditGraphNode?): EditGraphNode
	return {
		x = x,
		y = y,
		prev = prev,
	}
end

-- true if a[x+1] == b[y+1]; indicates an EQUAL operation (no diff) is valid
local function hasDiagonalEdge(node: EditGraphNode, a: string | { string }, b: string | { string }): boolean
	local x, y = node.x, node.y
	if typeof(a) == "table" and typeof(b) == "table" then
		return x < #a and y < #b and a[x + 1] == b[y + 1]
	end
	a = a :: string
	b = b :: string
	return x < #a and y < #b and a:sub(x + 1, x + 1) == b:sub(y + 1, y + 1)
end

export type diffoperation = {
	key: "EQUAL" | "ADD" | "DELETE",
	text: string,
}

export type diff = { diffoperation }

local function edgeTodiff(curNode: EditGraphNode, a: string | { string }, b: string | { string }): diffoperation?
	-- maps stepping from curNode.prev -> curNode to a diff operation
	-- (n, n) -> (n+1, n) == DELETION of a[n]
	-- (n, n) -> (n, n+1) == ADDITION of b[n]
	-- (n, n) -> (n+1, n+1) == EQUAL (no diff)
	if not curNode.prev then
		return nil
	end

	local prev = curNode.prev
	local xdiff = curNode.x - prev.x
	local ydiff = curNode.y - prev.y
	if xdiff == 1 and ydiff == 1 then
		return {
			key = "EQUAL",
			text = if typeof(a) == "table" then a[curNode.x] else a:sub(curNode.x, curNode.x),
		}
	elseif xdiff == 1 then
		return {
			key = "DELETE",
			text = if typeof(a) == "table" then a[curNode.x] else a:sub(curNode.x, curNode.x),
		}
	else
		return {
			key = "ADD",
			text = if typeof(b) == "table" then b[curNode.y] else b:sub(curNode.y, curNode.y),
		}
	end
end

local function myersdiff(a: string | { string }, b: string | { string }): diff
	local start = editGraphNode(0, 0)
	local editGraphDeque = deque.new(start)

	local diff = {} :: diff
	local seen = {} :: { [string]: true }
	seen["0,0"] = true

	while #editGraphDeque do
		local curNode = editGraphDeque:popfront()

		-- we've reached bottom right vertex; indicates full edit from a -> b
		if curNode.x == #a and curNode.y == #b then
			-- reconstruct diff operations by tracing path from termination node to start
			while curNode.prev do
				local diffOperation = edgeTodiff(curNode, a, b) :: diffoperation
				table.insert(diff, diffOperation)
				curNode = curNode.prev
			end
			break
		end

		-- add neighbors (diag prioritzed, then deletion, then insertion)
		if hasDiagonalEdge(curNode, a, b) then
			local edgePositionStr = `{curNode.x + 1},{curNode.y + 1}`
			if not seen[edgePositionStr] then
				seen[edgePositionStr] = true
				editGraphDeque:pushfront(editGraphNode(curNode.x + 1, curNode.y + 1, curNode))
			end
			continue
		end

		if curNode.x < #a then
			local edgePositionStr = `{curNode.x + 1},{curNode.y}`
			if not seen[edgePositionStr] then
				seen[edgePositionStr] = true
				editGraphDeque:pushback(editGraphNode(curNode.x + 1, curNode.y, curNode))
			end
		end

		if curNode.y < #b then
			local edgePositionStr = `{curNode.x},{curNode.y + 1}`
			if not seen[edgePositionStr] then
				seen[edgePositionStr] = true
				editGraphDeque:pushback(editGraphNode(curNode.x, curNode.y + 1, curNode))
			end
		end
	end

	local i, j = 1, #diff
	while i < j do
		diff[i], diff[j] = diff[j], diff[i]
		i = i + 1
		j = j - 1
	end

	return diff
end

local function myersdiffbyline(a: string, b: string): diff
	return myersdiff(a:split("\n"), b:split("\n"))
end

local function myersdiffbychar(a: string, b: string): diff
	return myersdiff(a, b)
end

local function applydiff(
	diff: diff,
	a: string,
	options: {
		byChar: boolean?,
	}?
)
	local separator = if options and options.byChar then "" else "\n"
	local src = a:split(separator)

	local result = {}
	local srcCursor = 1 -- Points to the current char in src string
	for i, op in diff do
		if op.key == "EQUAL" then
			local actual = src[srcCursor]
			if actual ~= op.text then
				error(
					string.format(
						"Patch Error at op %d: Expected EQUAL '%s' but source had '%s'",
						i,
						op.text,
						tostring(actual)
					)
				)
			end

			table.insert(result, op.text)
			srcCursor = srcCursor + 1
		elseif op.key == "DELETE" then
			local actual = src[srcCursor]
			if actual ~= op.text then
				error(
					string.format(
						"Patch Error at op %d: Expected DELETE '%s' but source had '%s'",
						i,
						op.text,
						tostring(actual)
					)
				)
			end

			srcCursor = srcCursor + 1
		elseif op.key == "ADD" then
			table.insert(result, op.text)
		end
	end

	return table.concat(result, separator)
end

return table.freeze({
	myersdiffbyline = myersdiffbyline,
	myersdiffbychar = myersdiffbychar,
	applydiff = applydiff, -- this is mainly a testing utility; maybe we prefix with _
})
