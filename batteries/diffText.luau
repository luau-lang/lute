local deque = require("@batteries/deque")
local style = require("@batteries/style")
local colors = style.colors

--[[
Algorithm Approach:
	- BFS on 'edit' graph, consistent with the structure of myers diff's graph
	- To mirror myers diff's greedy approach that prioritizes diagonal edits (represents no diff, operations where we keep a char),
	-- we will always push diagonal edges to the front of the queue and other edges to the backblu
	-- Recall:
	-- 	moving from (n, n) to (n +1, n) represents DELETE stringA[n] (and a weight of 1)
	--  moving from (n, n) to (n, n + 1) represents ADD stringB[n] (and a weight of 1)
	-- moving from (x, y) to (x + 1, y + 1) represents EQUAL (no operation) and is only possible if stringA[x] == stringB[y]

	-- we need to check neighbors, at each node, according to above logic
]]

-- hold current position, and prev node (so we can reconstruct path at end)
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

local function hasDiagonalEdge(node: EditGraphNode, a: string | { string }, b: string | { string })
	local x, y = node.x, node.y
	if typeof(a) == "table" and typeof(b) == "table" then
		return x < #a and y < #b and a[x + 1] == b[y + 1]
	end
	a = a :: string
	b = b :: string
	return x < #a and y < #b and a:sub(x + 1, x + 1) == b:sub(y + 1, y + 1)
end

type DiffOperation = {
	key: "EQUAL" | "ADD" | "DELETE",
	text: string,
	position: number?,
}

type Diff = { DiffOperation }

local function edgeToDiff(curNode: EditGraphNode, a: string | { string }, b: string | { string }): DiffOperation
	local prev = curNode.prev :: EditGraphNode
	local xDiff = curNode.x - prev.x
	local yDiff = curNode.y - prev.y
	if xDiff == 1 and yDiff == 1 then
		return {
			key = "EQUAL",
			text = if typeof(a) == "table" then a[curNode.x] else a:sub(curNode.x, curNode.x),
			position = curNode.y,
		}
	elseif xDiff == 1 then
		return {
			key = "DELETE",
			text = if typeof(a) == "table" then a[curNode.x] else a:sub(curNode.x, curNode.x),
			position = curNode.x,
		}
	else
		return {
			key = "ADD",
			text = if typeof(b) == "table" then b[curNode.y] else b:sub(curNode.y, curNode.y),
			position = curNode.y,
		}
	end
end

local function myersdiff(a: string | { string }, b: string | { string })
	local start = editGraphNode(0, 0)
	local editGraphDeque = deque.new(start)

	local diff = {}
	local seen = {} :: { [number]: { [number]: true } }
	-- lua dumb, have to do this weird mapping since we can't use EditGraphNode directly (it will use table memory address equivalence, not value equivalence for hashing)
	seen[0] = {}
	seen[0][0] = true

	while editGraphDeque.len > 0 do
		local curNode = editGraphDeque:pop()
		if not seen[curNode.x] then
			seen[curNode.x] = {}
		end
		if not seen[curNode.x + 1] then
			seen[curNode.x + 1] = {}
		end

		-- evaluate termination condition (we are at #a, #b)
		if curNode.x == #a and curNode.y == #b then
			-- traversal finished; now we need to reconstruct the graph
			while curNode.prev do
				local diffOperation = edgeToDiff(curNode, a, b)
				table.insert(diff, 1, diffOperation)
				curNode = curNode.prev
			end
			break
		end

		-- add neighbors (diag prioritzed, then deletion, then insertion)
		if hasDiagonalEdge(curNode, a, b) then
			if not seen[curNode.x + 1][curNode.y + 1] then
				seen[curNode.x + 1][curNode.y + 1] = true
				editGraphDeque:prepend(editGraphNode(curNode.x + 1, curNode.y + 1, curNode))
			end
			continue
		end

		if curNode.x < #a then
			if not seen[curNode.x + 1][curNode.y] then
				seen[curNode.x + 1][curNode.y] = true
				editGraphDeque:append(editGraphNode(curNode.x + 1, curNode.y, curNode))
			end
		end

		if curNode.y < #b then
			if not seen[curNode.x][curNode.y + 1] then
				seen[curNode.x][curNode.y + 1] = true
				editGraphDeque:append(editGraphNode(curNode.x, curNode.y + 1, curNode))
			end
		end
	end

	return diff
end

local function myersdiffbyline(a: string, b: string)
	return myersdiff(a:split("\n"), b:split("\n"))
end

local function myersdiffbychar(a: string, b: string)
	return myersdiff(a, b)
end

local function printDiffByLine(a: string, b: string)
	local diff = myersdiffbyline(a, b)
	for _, op in diff do
		print(
			if op.key == "ADD"
				then style.bold(style.color(colors.green, `+ {op.text} {op.position}`))
				elseif op.key == "DELETE" then style.bold(style.color(colors.red, `- {op.text} {op.position}`))
				else `{op.text} {op.position}`
		)
	end
end

local function applyDiff(diff: Diff, a: string, separator: string)
	local src = a:split(separator)

	local result = {}
	local srcCursor = 1 -- Points to the current char in Source
	for i, op in diff do
		if op.key == "EQUAL" then
			-- VALIDATION: Does the source actually have this char here?
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

			-- Apply: Add to result, consume source
			table.insert(result, op.text)
			srcCursor = srcCursor + 1
		elseif op.key == "DELETE" then
			-- VALIDATION: Are we deleting what we think we are?
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

local function applyCharDiff(diff: Diff, a: string)
	return applyDiff(diff, a, "")
end

local function applyLineDiff(diff: Diff, a: string)
	return applyDiff(diff, a, "\n")
end

return {
	bychar = myersdiffbychar,
	byline = myersdiffbyline,
	applylinediff = applyLineDiff,
	aplychardiff = applyCharDiff,
	printdiffbyline = printDiffByLine,
	-- TODO: printByChar
}
