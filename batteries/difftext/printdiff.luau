local richterm = require("@batteries/richterm")
local myersdiff = require("./myersdiff")
local myersdiffbychar = myersdiff.myersdiffbychar
local myersdiffbyline = myersdiff.myersdiffbyline

type Diff = myersdiff.Diff

-- Collects consecutive DELETEs and/or ADDs starting at index i
-- Returns: deletes array, adds array, new index position
local function collectConsecutiveChanges(diff: Diff, startIndex: number): ({ string }, { string }, number)
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

local function visualizeCharDiff(a: string, b: string)
	local charOps = myersdiffbychar(a, b)
	-- diffs two strings by char and returns colored visual for src and destination text
	local srcVisual = ""
	local destVisual = ""

	for _, op in charOps do
		if op.key == "EQUAL" then
			srcVisual ..= richterm.red(op.text)
			destVisual ..= richterm.green(op.text)
		elseif op.key == "DELETE" then
			srcVisual ..= richterm.bgRed(op.text)
		elseif op.key == "ADD" then
			destVisual ..= richterm.bgGreen(op.text)
		end
	end

	return srcVisual, destVisual
end

local function printDiffByLineDetailed(a: string, b: string)
	local diff = myersdiffbyline(a, b)
	local i = 1
	local result = ""
	while i <= #diff do
		local op = diff[i]

		if op.key == "DELETE" or op.key == "ADD" then
			local deletes, adds
			deletes, adds, i = collectConsecutiveChanges(diff, i)
			local pair = #deletes == 1 and #adds == 1
			if pair then
				local srcLine, destLine = visualizeCharDiff(deletes[1], adds[1])
				result ..= richterm.red("- ") .. srcLine .. "\n"
				result ..= richterm.green("+ ") .. destLine
				if i < #diff then
					result ..= "\n"
				end
			else
				for j, deleted in deletes do
					result ..= richterm.red(`- {deleted}\n`)
				end
				for j, added in adds do
					result ..= richterm.green(`+ {added}\n`)
				end
			end
		else -- EQUAL
			result ..= op.text
			if i <= #diff then
				result ..= "\n"
			end
			i += 1
		end
	end
	return result
end

local function printDiff(
	a: string,
	b: string,
	options: {
		detailed: boolean?,
		-- sideBySide: boolean?
	}?
)
	if options then
		if options.detailed then
			return printDiffByLineDetailed(a, b)
		end
	end

	local result = ""
	local diff = myersdiffbyline(a, b)
	for i, op in diff do
		result ..= if op.key == "ADD"
			then richterm.brightGreen(`+ {op.text}`)
			elseif op.key == "DELETE" then richterm.brightRed(`- {op.text}`)
			else `{op.text}`
		if i < #diff then
			result ..= "\n"
		end
	end
	return result
end

return printDiff
