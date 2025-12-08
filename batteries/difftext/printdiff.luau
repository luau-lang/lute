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

local function formatLineWithSideHeader(
	operation: types.diffoperationkey,
	line: string,
	maxNumWidth: number,
	lineNumbers: {
		oldLine: number?,
		newLine: number?,
	}?
)
	-- each line should be:SPACE/OP {oldLine} {newLine}|
	-- we want numbers to be right aligned with the |
	-- so we should just padd on the left of oldline, depending on how many chars are in our numbers tg
	-- we want every side header to be of length: 11 (we line nums accounting for 8 of those)
	local newLineLen = if lineNumbers then #tostring(lineNumbers.newLine or "") else 0
	local oldLineLen = if lineNumbers then #tostring(lineNumbers.oldLine or "") else 0
	local function padding(leftoverSpace: number)
		return (" "):rep(leftoverSpace)
	end
	local commonAvailableSpace = (maxNumWidth * 2) - (oldLineLen + newLineLen)
	local commonPadding = padding(commonAvailableSpace)
	local removalPadding = padding(commonAvailableSpace - 1) -- subtract one to account for additional space on the right side of deletion (deletion always of format {oldline}  |)
	if operation == "EQUAL" then
		return if lineNumbers then `  {commonPadding}{lineNumbers.oldLine} {lineNumbers.newLine}| {line}` else line
	elseif operation == "ADD" then
		return if lineNumbers
			then richterm.brightGreen(`+ {commonPadding} {lineNumbers.newLine}| {line}`)
			else richterm.brightGreen(`+ {line}`)
	elseif operation == "DELETE" then
		return if lineNumbers
			then richterm.brightRed(`- {removalPadding}{lineNumbers.oldLine}  | {line}`)
			else richterm.brightRed(`- {line}`)
	end

	return "" -- unreachable
end
-- mabye just format the header instead of whole line? will be more extensible then and perhaps clear up some of the code... 

local function printDiffByLineDetailed(a: string, b: string, includeLineNumbers: boolean?): string
	local maxNumLines = math.max(#a:split("\n"), #b:split("\n"))
	local maxLineDigits = #tostring(maxNumLines)
	local diff = myersdiffbyline(a, b)
	local i = 1
	local result: { string } = {}
	local oldLine, newLine = 1, 1
	while i <= #diff do
		local op = diff[i]

		if op.key == "DELETE" or op.key == "ADD" then
			local deletes, adds
			deletes, adds, i = collectConsecutiveChanges(diff, i)
			local pair = #deletes == 1 and #adds == 1
			if pair then
				local srcLine, destLine = visualizeCharDiff(deletes[1], adds[1])
				table.insert(
					result,
					formatLineWithSideHeader(
						"DELETE",
						srcLine,
						maxLineDigits,
						if includeLineNumbers then { oldLine = oldLine } else nil
					)
				)
				table.insert(
					result,
					formatLineWithSideHeader(
						"ADD",
						destLine,
						maxLineDigits,
						if includeLineNumbers then { newLine = newLine } else nil
					)
				)
				oldLine, newLine = oldLine + 1, newLine + 1
			else
				for j, deleted in deletes do
					table.insert(
						result,
						formatLineWithSideHeader(
							"DELETE",
							deleted,
							maxLineDigits,
							if includeLineNumbers then { oldLine = oldLine } else nil
						)
					)
					oldLine += 1
				end
				for j, added in adds do
					table.insert(
						result,
						formatLineWithSideHeader(
							"ADD",
							added,
							maxLineDigits,
							if includeLineNumbers then { newLine = newLine } else nil
						)
					)
					newLine += 1
				end
			end
		else -- EQUAL
			table.insert(
				result,
				formatLineWithSideHeader(
					"EQUAL",
					op.text,
					maxLineDigits,
					if includeLineNumbers then { oldLine = oldLine, newLine = newLine } else nil
				)
			)
			oldLine, newLine = oldLine + 1, newLine + 1
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
		includeLineNumbers: boolean?,
	}?
): string
	if options then
		if options.detailed then
			return printDiffByLineDetailed(a, b, options.includeLineNumbers)
		end
	end

	local result = {} :: { string }
	local diff = myersdiffbyline(a, b)
	local maxNumLines = math.max(#a:split("\n"), #b:split("\n"))
	local maxLineDigits = #tostring(maxNumLines)
	local oldLine, newLine = 1, 1
	for i, op in diff do
		if op.key == "ADD" then
			table.insert(
				result,
				formatLineWithSideHeader(op.key, op.text, maxLineDigits, if options and options.includeLineNumbers then {
					newLine = newLine,
				} else nil)
			)
			newLine += 1
		elseif op.key == "DELETE" then
			table.insert(
				result,
				formatLineWithSideHeader(op.key, op.text, maxLineDigits, if options and options.includeLineNumbers then {
					oldLine = oldLine,
				} else nil)
			)
			oldLine += 1
		else
			table.insert(
				result,
				formatLineWithSideHeader(op.key, op.text, maxLineDigits, if options and options.includeLineNumbers then {
					oldLine = oldLine,
					newLine = newLine,
				} else nil)
			)
			oldLine, newLine = oldLine + 1, newLine + 1
		end
	end
	return table.concat(result, "\n")
end

return prettydiff
