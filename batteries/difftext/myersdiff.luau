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

local function hasDiagonalEdge(node: EditGraphNode, a: string | { string }, b: string | { string })
	local x, y = node.x, node.y
	if typeof(a) == "table" and typeof(b) == "table" then
		return x < #a and y < #b and a[x + 1] == b[y + 1]
	end
	a = a :: string
	b = b :: string
	return x < #a and y < #b and a:sub(x + 1, x + 1) == b:sub(y + 1, y + 1)
end

export type DiffOperation = {
	key: "EQUAL" | "ADD" | "DELETE",
	text: string,
	position: number?,
}

export type Diff = { DiffOperation }

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
		local curNode = editGraphDeque:popfront()

		if not seen[curNode.x] then
			seen[curNode.x] = {}
		end
		if not seen[curNode.x + 1] then
			seen[curNode.x + 1] = {}
		end

		-- we've reached bottom right vertex; indicates full edit from a -> b
		if curNode.x == #a and curNode.y == #b then
			-- reconstruct diff operations by tracing path from termination node to start
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
				editGraphDeque:pushfront(editGraphNode(curNode.x + 1, curNode.y + 1, curNode))
			end
			continue
		end

		if curNode.x < #a then
			if not seen[curNode.x + 1][curNode.y] then
				seen[curNode.x + 1][curNode.y] = true
				editGraphDeque:pushback(editGraphNode(curNode.x + 1, curNode.y, curNode))
			end
		end

		if curNode.y < #b then
			if not seen[curNode.x][curNode.y + 1] then
				seen[curNode.x][curNode.y + 1] = true
				editGraphDeque:pushback(editGraphNode(curNode.x, curNode.y + 1, curNode))
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

local function applyDiff(
	diff: Diff,
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
	applydiff = applyDiff,
})
