local deque = require("@batteries/collections/deque")
local tableext = require("@std/tableext")
local types = require("./types")

type diffoperation = types.diffoperation
type diff = types.diff

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
	if typeof(a) == "table" then
		if typeof(b) == "table" then
			return x < #a and y < #b and a[x + 1] == b[y + 1]
		else
			error("hasDiagonalEdge inputs should have the same type.")
		end
	elseif typeof(b) == "table" then
		error("hasDiagonalEdge inputs should have the same type.")
	end

	return x < #a and y < #b and a:sub(x + 1, x + 1) == b:sub(y + 1, y + 1)
end

local function edgeTodiff(curNode: EditGraphNode, a: string | { string }, b: string | { string }): diffoperation?
	-- maps stepping from curNode.prev -> curNode to a diff operation
	-- (n-1, n) -> (n, n) == DELETION of a[n]
	-- (n, n-1) -> (n, n) == ADDITION of b[n]
	-- (n-1, n-1) -> (n, n) == EQUAL (a[n] == b[n])
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
			local edgeOp = edgeTodiff(curNode, a, b)
			while edgeOp do
				table.insert(diff, edgeOp)
				curNode = curNode.prev
				edgeOp = if curNode then edgeTodiff(curNode, a, b) else nil
			end
			break
		end

		-- add neighbors (diag prioritzed, then deletion, then insertion)
		if hasDiagonalEdge(curNode, a, b) then
			-- algorithm optimizes for diagonal edges since they represent no diff. We want the shortest-edit-sequence (least # of diff operations)
			-- so diagonal edges representing equality in a[n+1] & b[n+1] is always preferred
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

	tableext.reverse(diff, true)
	return diff
end

local function myersdiffbyline(a: string, b: string): diff
	return myersdiff(a:split("\n"), b:split("\n"))
end

local function myersdiffbychar(a: string, b: string): diff
	return myersdiff(a, b)
end

return table.freeze({
	myersdiffbyline = myersdiffbyline,
	myersdiffbychar = myersdiffbychar,
})
