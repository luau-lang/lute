local richterm = require("@batteries/richterm")
local myersdiff = require("./myersdiff")
local myersdiffbychar = myersdiff.myersdiffbychar
local myersdiffbyline = myersdiff.myersdiffbyline
local types = require("./types")

type diff = types.diff

-- Collects consecutive DELETEs and/or ADDs starting at index i
-- Returns: deletes array, adds array, new index position
local function collectConsecutiveChanges(diff: diff, startIndex: number): ({ string }, { string }, number)
	local i = startIndex
	local deletes = {}
	while i <= #diff and diff[i].key == "DELETE" do
		table.insert(deletes, diff[i].text)
		i += 1
	end

	local adds = {}
	while i <= #diff and diff[i].key == "ADD" do
		table.insert(adds, diff[i].text)
		i += 1
	end

	return deletes, adds, i
end

local function visualizeCharDiff(a: string, b: string): (string, string)
	local charOps = myersdiffbychar(a, b)
	-- diffs two strings by char and returns colored visual for src and destination text
	local srcVisual = {}
	local destVisual = {}

	for _, op in charOps do
		if op.key == "EQUAL" then
			table.insert(srcVisual, richterm.brightRed(op.text))
			table.insert(destVisual, richterm.brightGreen(op.text))
		elseif op.key == "DELETE" then
			table.insert(srcVisual, richterm.bgRed(op.text))
		elseif op.key == "ADD" then
			table.insert(destVisual, richterm.bgGreen(op.text))
		end
	end

	return table.concat(srcVisual, ""), table.concat(destVisual, "")
end

local function printDiffByLineDetailed(a: string, b: string): string
	local diff = myersdiffbyline(a, b)
	local i = 1
	local result: { string } = {}
	while i <= #diff do
		local op = diff[i]

		if op.key == "DELETE" or op.key == "ADD" then
			local deletes, adds
			deletes, adds, i = collectConsecutiveChanges(diff, i)
			local pair = #deletes == 1 and #adds == 1
			if pair then
				local srcLine, destLine = visualizeCharDiff(deletes[1], adds[1])
				table.insert(result, richterm.brightRed("- ") .. srcLine)
				table.insert(result, richterm.brightGreen("+ ") .. destLine)
			else
				for j, deleted in deletes do
					table.insert(result, richterm.brightRed(`- {deleted}`))
				end
				for j, added in adds do
					table.insert(result, richterm.brightGreen(`+ {added}`))
				end
			end
		else -- EQUAL
			table.insert(result, op.text)
			i += 1
		end
	end
	return table.concat(result, "\n")
end

local function prettydiff(
	a: string,
	b: string,
	options: {
		detailed: boolean?,
	}?
): string
	if options then
		if options.detailed then
			return printDiffByLineDetailed(a, b)
		end
	end

	local result = {} :: { string }
	local diff = myersdiffbyline(a, b)
	for i, op in diff do
		table.insert(
			result,
			if op.key == "ADD"
				then richterm.brightGreen(`+ {op.text}`)
				elseif op.key == "DELETE" then richterm.brightRed(`- {op.text}`)
				else `{op.text}`
		)
	end
	return table.concat(result, "\n")
end

return prettydiff
